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

;*************************************************
;	Data section
;*************************************************
msgLoading	db "Preparing to load operating system...", 0x0d, 0x0a, 0x00

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
	;	Print loading message
	;----------------------------------------------
	mov	si, msgLoading
	call	puts16

	;----------------------------------------------
	;	Install our GDT
	;----------------------------------------------
	call installGDT

	;----------------------------------------------
	;	Enable a20
	;----------------------------------------------
	call enableA20_output_port

	;----------------------------------------------
	;	Go into pmode
	;----------------------------------------------
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

msgHello32	db "Hello 32-Bit World", 0x0a, 0x00
msgNext		db "This is a different colour", 0x0a, 0x00

stage3:
	;----------------------------------------------
	;	Set registers
	;----------------------------------------------
	mov	ax, 0x10	; Set data segments to data selector (0x10)
	mov	ds, ax
	mov	ss, ax
	mov	es, ax
	mov	esp, 0x90000	; Stack begins from 0x90000

	call	clrScr32	; Clear the screen
	mov	bx, 0x0		; Set cursor pos to 0,0
	call	movCur
	mov	ebx, msgHello32	; Say hello
	call	puts32

	; Change attribute
	mov	BYTE [_CharAttr], 0b01101111
	mov	ebx, msgNext
	call	puts32

;*************************************************
;	Stop execution
;*************************************************
stop:
	cli
	hlt
