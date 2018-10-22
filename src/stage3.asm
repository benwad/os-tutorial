;*************************************************
;	stage3.asm - The Kernel
;	A basic 32 bit binary kernel running
;*************************************************
org 0x100000		; Kernel starts at 1MB

bits 32			; 32-bit protected mode

jmp stage3

%include "stdio.inc"

msgWelcome	db	0x0a, 0x0a, "            - OS Development Series -"
		db	0x0a, 0x0a, "          MOS 32-bit kernel executing..", 0x0a, 0x0

stage3:
	;----------------------------------------------
	;	Set up stack
	;----------------------------------------------
	mov	ax, 0x10	; Set data segments to data selector (0x10)
	mov	ds, ax
	mov	ss, ax
	mov	es, ax
	mov	esp, 0x90000	; Stack begins at 0x90000

	;----------------------------------------------
	;	Clear screen and print success
	;----------------------------------------------
	call	clrScr32
	mov	ebx, msgWelcome
	call	puts32

	;----------------------------------------------
	;	Stop execution
	;----------------------------------------------
	cli
	hlt

