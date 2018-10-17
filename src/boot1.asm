;*************************************************
;	boot1.asm
;		- A simple bootloader
;
;	Operating Systems development tutorial
;*************************************************
bits	16		; We are still in 16 bit Real Mode

org	0		; We will set registers later

start:
	jmp	main	; Jump to start of bootloader

;*************************************************
;	BIOS Parameter Block
;*************************************************

bpbOEM			DB "My OS   "
bpbBytesPerSector:	DW 512
bpbSectorsPerCluster:	DB 1
bpbReservedSectors:	DW 1
bpbNumberOfFATs:	DB 2
bpbRootEntries:		DW 224
bpbTotalSectors:	DW 2880
bpbMedia:		DB 0xF8
bpbSectorsPerFAT:	DW 9
bpbSectorsPerTrack:	DW 18
bpbHeadsPerCylinder:	DW 2
bpbHiddenSectors:	DD 0
bpbTotalSectorsBig:	DD 0
bsDriveNumber:		DB 0
bsUnused:		DB 0
bsExtBootSignature:	DB 0x29
bsSerialNumber:		DD 0xa0a1a2a3
bsVolumeLabel:		DB "MOS FLOPPY "
bsFileSystem:		DB "FAT12   "

;*************************************************
;	Prints a string
;	DS=>SI: 0 terminated string
;*************************************************

print:
	lodsb			; Load next byte from string from SI to AL
	or	al, al		; al=current character
	jz	printDone	; null terminator found
	mov	ah, 0x0e	; get next character
	int	0x10
	jmp	print
printDone:
	ret

;*************************************************
;	Reads a series of sectors
;	CX => Number of sectors to read
;	AX => Starting sector
;	ES:BX => Buffer to read to
;*************************************************

readSectors:
	.main
		mov	di, 0x0005	; Five retries for error
	.sectorLoop
		push	ax
		push	bx
		push	cx
		call	LbaChs				; Convert starting sector to CHS
		mov	ah, 0x02			; BIOS read sector
		mov	al, 0x01			; read one sector
		mov	ch, BYTE [absoluteTrack]	; track
		mov	cl, BYTE [absoluteSector]	; sector
		mov	dh, BYTE [absoluteHead]		; head
		mov	dl, BYTE [bsDriveNumber]	; drive
		int	0x13				; Invoke BIOS
		jnc	.success			; test for read error
		xor	ax, ax				; BIOS reset disk
		int	0x13				; Invoke BIOS again
		dec	di				; Decrement error counter
		pop	cx
		pop	bx
		pop	ax
		jnz	.sectorLoop			; Attempt to read again
		int	0x18
	.success
		mov	si, msgProgress
		call	print
		pop	cx
		pop	bx
		pop	ax
		add	bx, WORD [bpbBytesPerSector]	; Queue next buffer
		inc	ax				; Queue next sector
		loop	.main				; Read next sector
		ret

;*************************************************
;	Convert CHS to LBA
;	LBA = (cluster - 2) * sectors per cluster
;*************************************************
clusterLba:
	sub	ax, 0x0002			; Zero base cluster number
	xor	cx, cx
	mov	cl, BYTE [bpbSectorsPerCluster]	; Convert byte to word
	mul	cx
	add	ax, WORD [dataSector]		; Base data sector
	ret

;*************************************************
;	Convert LBA to CHS
;	Absolute sector = (logical sector / sectors per track) + 1
;	Absolute head	= (logical sector / sectors per track) MOD number of heads
;	Absolute track	= logical sector / (sectors per track * number of heads)
;*************************************************
LbaChs:
	xor	dx, dx				; Prepare dx:ax for operation
	div	WORD [bpbSectorsPerTrack]	; Calculate
	inc	dl				; Adjust for sector 0
	mov	BYTE [absoluteSector], dl
	xor	dx, dx				; Prepare dx:ax for operation
	div	WORD [bpbHeadsPerCylinder]	; Calculate
	mov	BYTE [absoluteHead], dl
	mov	BYTE [absoluteTrack], al
	ret


;*************************************************
;	Bootloader entry point
;*************************************************

main:
	;*************************************************
	;	Code located at 0000:7C00, adjust segment registers
	;*************************************************
		cli			; Disable interrupts
		mov	ax, 0x07c0	; Setup registers to point to our segment
		mov	ds, ax
		mov	es, ax
		mov	fs, ax
		mov	gs, ax

	;*************************************************
	;	Create stack
	;*************************************************
		mov	ax, 0x0000	; Set the stack
		mov	ss, ax
		mov	sp, 0xffff
		sti			; Restore interrupts

	;*************************************************
	;	Display loading message
	;*************************************************
		mov	si, msgLoading
		call	print

	;*************************************************
	;	Load root directory table
	;*************************************************
	load_root:
		; Compute size of root directory and store in 'cx'
		xor	cx, cx
		xor	dx, dx
		mov	ax, 0x0020			; 32-byte directory entry
		mul	WORD [bpbRootEntries]		; total size of directory
		div	WORD [bpbBytesPerSector]	; sectors used by directory
		xchg	ax, cx

		; Compute location of root directory and store in 'ax'
		mov	al, BYTE [bpbNumberOfFATs]	; Number of FATs
		mul	WORD [bpbSectorsPerFAT]		; sectors used by FATs
		add	ax, WORD [bpbReservedSectors]	; Adjust for bootsector
		mov	WORD [dataSector], ax		; base of root directory
		add	WORD [dataSector], cx
		
		; Read root directory into memory (7c00:0200)
		mov	bx, 0x0200			; Copy root dir above bootcode
		call	readSectors

		;*************************************************
		;	Find stage 2
		;*************************************************

		; Browse root directory for binary image
		mov	cx, WORD [bpbRootEntries]	; Load loop counter
		mov	di, 0x0200			; Locate first root entry
	.loop:
		push	cx
		mov	cx, 0x000b			; 11-character name
		mov	si, imageName			; Image name to find
		push	di
	rep	cmpsb					; Test for entry match
		pop	di
		je	load_fat
		pop	cx
		add	di, 0x0020			; Queue next directory entry
		loop	.loop
		jmp	failure

	;*************************************************
	;	Load root directory table
	;*************************************************
	load_fat:
		; Save starting cluster of boot image
		mov	si, msgCRLF
		call	print
		mov	dx, WORD [di + 0x001a]
		mov	WORD [cluster], dx		; File's first cluster

		; Compute size of FAT and store in 'cx'
		xor	ax, ax
		mov	al, BYTE [bpbNumberOfFATs]	; Number of FATs
		mul	WORD [bpbSectorsPerFAT]		; Sectors used by FATs
		mov	cx, ax

		; Compute location of FAT and store in 'ax'
		mov	ax, WORD [bpbReservedSectors]	; Adjust for bootsector

		; Read FAT into memory (7c00:0200)
		mov	bx, 0x0200			; Copy FAT above bootcode
		call	readSectors

		; Read image file into memory
		mov	si, msgCRLF
		call	print
		mov	ax, 0x0050
		mov	es, ax				; Destination for image
		mov	bx, 0x0000			; Destination for image
		push	bx

	;*************************************************
	;	Load stage 2
	;*************************************************
	load_image:
		mov	ax, WORD [cluster]		; Cluster to read
		pop	bx				; Buffer to read into
		call	clusterLba			; Convert cluster to LBA
		xor	cx, cx
		mov	cl, BYTE [bpbSectorsPerCluster]	; Sectors to read
		call	readSectors
		push	bx

		; Compute next cluster
		mov	ax, WORD [cluster]		; Identify current cluster
		mov	cx, ax				; Copy current cluster
		mov	dx, ax				; Copy current cluster
		shr	dx, 0x0001			; Divide by two
		add	cx, dx				; Sum for (3/2)
		mov	bx, 0x0200			; Location of FAT in memory
		add	bx, cx				; Index into FAT
		mov	dx, WORD [bx]			; Read two bytes from FAT
		test	ax, 0x0001
		jnz	.odd_cluster

	.even_cluster:
		and	dx, 0000111111111111b		; Take low 12 bits
		jmp	.done

	.odd_cluster:
		shr	dx, 0x0004			; Take high 12 bits

	.done:
		mov	WORD [cluster], dx		; Store new cluster
		cmp	dx, 0x0ff0			; Test for end of file
		jb	load_image

	done:
		mov	si, msgCRLF
		call	print
		push	WORD 0x0050
		push	WORD 0x0000
		retf

	failure:
		mov	si, msgFailure
		call	print
		mov	ah, 0x00
		int	0x16				; Await keypress
		int	0x19				; Warm boot computer

	absoluteSector	db	0x00
	absoluteHead	db	0x00
	absoluteTrack	db	0x00

	dataSector	dw	0x0000
	cluster		dw	0x0000
	imageName	db	"KRNLDR  SYS"
	msgLoading	db	0x0d, 0x0a, "Loading Boot Image ", 0x0d, 0x0a, 0x00
	msgCRLF		db	0x0d, 0x0a, 0x00
	msgProgress	db	".", 0x00
	msgFailure	db	0x0d, 0x0a, "Error: Press any key to reboot", 0x0a, 0x00

times 510 - ($-$$) db 0	; Has to be 512 bytes. Clear the rest of the bytes with 0

dw 0xaa55		; Boot signature
