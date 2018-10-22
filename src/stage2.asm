bits	16

; 0x500 to 0x7bff is unused above the BIOS data area.
; We are loaded at 0x500 (0x50:0)
org 0x500

jmp main		; Jump to main

;*************************************************
;	Preprocessor directives
;*************************************************
%include "stdio.inc"
%include "gdt.inc"
%include "a20.inc"
%include "fat12.inc"
%include "common.inc"

;*************************************************
;	Data section
;*************************************************
msgLoading	db 0x0d, 0x0a, "Searching for operating system...", 0x00
msgFailure	db 0x0d, 0x0a, "*** FATAL: MISSING OR CORRUPT KRNL.SYS. Press any key to reboot.", 0x0d, 0x0a, 0x0a, 0x00

;*************************************************
;	ENTRY POINT FOR STAGE 2
;
;		- Store BIOS information
;		- Load kernel
;		- Install GDT; go into protected mode (stage 3)
;		- Jump to stage 3
;*************************************************

main:
	;----------------------------------------------
	;	Setup segments and stack
	;----------------------------------------------
	cli			; Clear interrupts
	xor	ax, ax		; Null segments
	mov	ds, ax
	mov	es, ax
	mov	ax, 0x9000	; Stack begins at 0x9000-0xffff
	mov	ss, ax
	mov	sp, 0xffff
	sti			; Enable interrupts

	;----------------------------------------------
	;	Install our GDT
	;----------------------------------------------
	call installGDT

	;----------------------------------------------
	;	Enable a20
	;----------------------------------------------
	call enableA20_output_port

	;----------------------------------------------
	;	Print loading message
	;----------------------------------------------
	mov	si, msgLoading
	call	puts16

	;----------------------------------------------
	;	Initialise filesystem
	;----------------------------------------------
	call	loadRoot		; Load root directory table

	;----------------------------------------------
	;	Load kernel
	;----------------------------------------------
	mov	ebx, 0			; BX:BP points to buffer to load to
	mov	ebp, IMAGE_RMODE_BASE
	mov	esi, imageName		; Our file to load
	call	loadFile		; Load our file
	mov	DWORD [imageSize], ecx	; Size of our kernel
	cmp	ax, 0			; Test for success
	je	enterStage3		; Yep -- onto stage 3!
	mov	si, msgFailure		; Nope -- print error
	call	puts16
	mov	ah, 0
	int	0x16			; Await keypress
	int	0x19			; Warm boot computer
	cli				; If we get here, something went really wrong
	hlt

	;----------------------------------------------
	;	Go into pmode
	;----------------------------------------------
enterStage3:
	cli
	mov	eax, cr0		; Set bit 0 in cr0 - enter pmode
	or	eax, 0b1
	mov	cr0, eax

	jmp	CODE_DESC:stage3

	; Note: Do NOT re-enable interrupts! Doing so will triple-fault
	; We will fix this in stage 3

;*************************************************
;	ENTRY POINT FOR STAGE 3
;*************************************************
bits 32			; Welcome to the 32 bit world!

stage3:
	;----------------------------------------------
	;	Set registers
	;----------------------------------------------
	mov	ax, DATA_DESC	; Set data segments to data selector (0x10)
	mov	ds, ax
	mov	ss, ax
	mov	es, ax
	mov	esp, 0x90000	; Stack begins from 0x90000

	; Copy kernel to 1MB (0x10000)
copyImage:
	mov	eax, DWORD [imageSize]
	movzx	ebx, word [bpbBytesPerSector]
	mul	ebx
	mov	ebx, 4
	div	ebx
	cld
	mov	esi, IMAGE_RMODE_BASE
	mov	edi, IMAGE_PMODE_BASE
	mov	ecx, eax
	rep	movsd				; Copy image to its protected mode address

	call	CODE_DESC:IMAGE_PMODE_BASE	; Execute our kernel!

;*************************************************
;	Stop execution
;*************************************************
stop:
	cli
	hlt
