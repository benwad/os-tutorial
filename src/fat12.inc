;*************************************************
;	fat12.inc
;	  - Functions for reading FAT12 volumes
;
;*************************************************

%ifndef __FAT12_INC_67343546FDCC56AAB872_INCLUDED__
%define __FAT12_INC_67343546FDCC56AAB872_INCLUDED__

bits	16

%include "floppy16.inc"

%define ROOT_OFFSET	0x2e00
%define FAT_SEG		0x2c0
%define ROOT_SEG	0x2e0

;*************************************************
;	loadRoot ()
;		- Load root directory table
;*************************************************

loadRoot:
	pusha					; Store registers
	push	es

	; Compute size of root directory and store in CX
	xor	cx, cx
	xor	dx, dx
	mov	ax, 32				; 32-byte directory entry
	mul	WORD [bpbRootEntries]		; Total size of directory
	div	WORD [bpbBytesPerSector]	; Sectors used by directory
	xchg	ax, cx				; Move into AX

	; Compute location of root directory and store in AX
	mov	al, BYTE [bpbNumberOfFATs]	; Number of FATs
	mul	WORD [bpbSectorsPerFAT]		; Sectors used by FATs
	add	ax, WORD [bpbReservedSectors]	; Adjust for bootsector
	mov	WORD [datasector], ax		; Base for root directory
	add	WORD [datasector], cx

	; Read root directory
	push	WORD ROOT_SEG
	pop	es
	mov	bx, 0x0				; Copy root dir
	call	readSectors			; Read in directory table
	pop	es
	popa					; Restore registers and return
	ret


;*************************************************
;	loadFAT ()
;		- Loads file allocation table
;
;	ES:DI => Root directory table
;*************************************************

loadFAT:
	pusha
	push	es

	; Compute size of FAT and store in CX
	xor	ax, ax
	mov	al, BYTE [bpbNumberOfFATs]	; Number of FATs
	mul	WORD [bpbSectorsPerFAT]
	mov	cx, ax

	; Compute location of FAT and store in AX
	mov	ax, WORD [bpbReservedSectors]

	; Read FAT into memory (overwrite our bootloader at 0x7c00)
	push	WORD FAT_SEG
	pop	es
	xor	bx, bx
	call	readSectors
	pop	es
	popa					; Restore registers and return
	ret



;*************************************************
;	findFile ()
;		- Search for filename in root table
;
;	DS:SI => Filename
;	Returns: AX => File index number in directory table. -1 if error.
;*************************************************
findFile:
	push	cx
	push	dx
	push	bx
	mov	bx, si				; Copy filename for later

	; Browse root directory for binary image
	mov	cx, WORD [bpbRootEntries]	; Load loop counter
	mov	di, ROOT_OFFSET			; Locate first root entry
	cld					; Clear direction flag

.loop:
	push	cx
	mov	cx, 11				; 11-character name. Image name is in SI
	mov	si, bx				; Image name is in BX
	push	di
	rep	cmpsb				; Test for entry match

	pop	di
	je	.found
	pop	cx
	add	di, 32				; Queue next directory entry
	loop	.loop
.notFound:
	pop	bx				; Restore registers and return
	pop	dx
	pop	cx
	mov	ax, -1				; Set error code
	ret
.found:
	pop	ax				; Return value in AX contains entry of file
	pop	bx				; Restore registers and return
	pop	dx
	pop	cx
	ret

;*************************************************
;	loadFile ()
;		- Load file
;	PARAM	ES:SI	=> File to load
;	PARAM	BX:BP	=> Buffer to load file into
;	RET	AX	=> -1 on error, 0 on success
;	RET	CX	=> Number of sectors loaded
;*************************************************
loadFile:
	xor	ecx, ecx
	push	ecx
.findFile:
	push	bx			; BX=>BP points to buffer to write to: store it for later
	push	bp

	call	findFile		; Find our file. ES:SI contains our filename

	cmp	ax, -1			; Check for error
	jne	.loadImagePre		; No error :) Load the FAT
	pop	bp			; Error :( Restore registers, set error code and return
	pop	bx
	pop	ecx
	mov	ax, -1
	ret
.loadImagePre:
	sub	edi, ROOT_OFFSET
	sub	eax, ROOT_OFFSET

	; Get starting cluster
	push	WORD ROOT_SEG
	pop	es
	mov	dx, WORD [es:di + 0x001a]	; ES:DI points to file entry in root directory table.
	mov	WORD [cluster], dx		; Reference the table for file's first cluster
	pop	bx				; Get location to write to so we don't screw up the stack
	pop	es
	push	bx				; Store location for later again
	push	es

	call	loadFAT				; Load the FAT to 0x7c00
.loadImage:
	mov	ax, WORD [cluster]		; Cluster to read
	pop	es
	pop	bx
	call	clusterLBA			; Convert cluster to LBA
	xor	cx, cx
	mov	cl, BYTE [bpbSectorsPerCluster]	; Sectors to read
	call	readSectors			; Read in cluster

	pop	ecx
	inc	ecx				; Increment sector count
	push	ecx

	push	bx				; Save registers for next iteration
	push	es

	mov	ax, FAT_SEG
	mov	es, ax
	xor	bx, bx

	;----------------------------------------------
	;	Determine if the end of the file is reached
	;----------------------------------------------
	; Compute next cluster
	mov	ax, WORD [cluster]		; Identify current cluster
	mov	cx, ax				; Copy current cluster
	mov	dx, ax				; Copy current cluster
	shr	dx, 0x0001			; Divide by two
	add	cx, dx				; Sum for (3/2)
	mov	bx, 0				; Location of FAT in memory
	add	bx, cx				; Index into FAT
	mov	dx, WORD [es:bx]		; Read two bytes from FAT
	test	ax, 0x0001
	jnz	.oddCluster

.evenCluster:
	and	dx, 0b0000111111111111		; Take low 12 bits
	jmp	.done

.oddCluster:
	shr	dx, 0x0004			; Take high 12 bits

.done:
	mov	WORD [cluster], dx		; Store new cluster
	cmp	dx, 0x0ff0			; Test for end of file marker (0xff)
	jb	.loadImage			; No? Go on to next cluster then

done:
	pop	es				; Restore all registers
	pop	bx
	pop	ecx
	xor	ax, ax				; Return success code
	ret


%endif ;__FAT12_INC_67343546FDCC56AAB872_INCLUDED__

