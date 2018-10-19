;********************************************
;	Enable A20 address line
;********************************************

%ifndef __A20_INC_67343546FDCC56AAB872_INCLUDED__
%define __A20_INC_67343546FDCC56AAB872_INCLUDED__

bits	16

;----------------------------------------------
;	Enables A20 line through keyboard controller
;----------------------------------------------
enableA20_kbd:
	cli
	push	ax
	mov	al, 0xdd	; Send enable a20 address line command
	out	0x64, al	; ...to the keyboard controller
	pop	ax
	ret

;----------------------------------------------
;	Enables a20 line through output port
;----------------------------------------------
enableA20_output_port:
	cli
	pusha

	call	wait_input
	mov	al, 0xad	; Disable keyboard command
	out	0x64, al	; ...to keyboard controller
	call	wait_input

	mov	al, 0xd0	; Read output port cmd
	out	0x64, al
	call	wait_output

	in	al, 0x60
	push	eax		; Get output port data and store it
	call	wait_input

	mov	al, 0xd1	; Write output port cmd
	out	0x64, al
	call	wait_input

	pop	eax
	or	al, 0b10	; Set bit a (enable a20)
	out	0x60, al	; Write out data back to output port

	call	wait_input
	mov	al, 0xae	; Enable keyboard
	out	0x64, al

	call	wait_input
	popa
	sti
	ret

	; Wait for innput buffer to be clear

wait_input:
	in	al, 0x64
	test	al, 0b10
	jnz	wait_input
	ret

wait_output:
	in	al, 0x64
	test	al, 0b01
	jz	wait_output
	ret

;----------------------------------------------
;	Enables a20 line through BIOS
;----------------------------------------------
enableA20_bios:
	pusha
	mov	ax, 0x2401
	int	0x15
	popa
	ret

;----------------------------------------------
;	Enables a20 line through system control port A
;----------------------------------------------
enableA20_sysControlA:
	push	ax
	mov	al, 0b10
	out	0x92, al
	pop	ax
	ret

%endif ;__A20_INC_67343546FDCC56AAB872_INCLUDED__

