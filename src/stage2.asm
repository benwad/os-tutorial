; Note: Here, we are executed like a normal
; COM program, but we are still in Ring 0.
; We will use this loader to set up 32 bit
; mode and basic exception handling.

; This loaded program will be our 32 bit kernel.

; We do not have the limitations of 512 bytes here,
; so we can add anything we want here!

org 0x0			; Offset to 0, we will set segments later

bits 16			; Still in real mode

; We are loaded at linear address 0x10000

jmp main		; Jump to main

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
;	Second stage loader entry point
;*************************************************

main:
	cli			; Clear interrupts
	push	cs		; Insure DS=CS
	pop	ds

	mov	si, msg
	call	print

	cli			; Clear interrupts to prevent triple faults
	hlt			; Halt the system

;*************************************************
;	Data section
;*************************************************

msg	db	"Preparing to load operating system...",13,10,0
