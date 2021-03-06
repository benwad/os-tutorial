;*************************************************
;	gdt.inc
;	  - Input/Output routines
;
;*************************************************

%ifndef __GDT_INC_67343546FDCC56AAB872_INCLUDED__
%define __GDT_INC_67343546FDCC56AAB872_INCLUDED__

bits	16

;*************************************************
;	installGDT()
;		- Install our GDT
;*************************************************

installGDT:
	cli			; Clear interrupts
	pusha			; Save registers
	lgdt	[toc]		; Load GDT into GDTR
	sti			; Enable interrupts
	popa			; Restore registers
	ret			; All done!

;*************************************************
;	Global Descriptor Table (GDT)
;*************************************************
gdt_data:
	dd 0 				; null descriptor
	dd 0 
 
; kernel space code (offset: 8 (0x8) bytes):
	dw 0FFFFh 			; limit low
	dw 0 				; base low
	db 0 				; base middle
	db 10011010b 			; access
	db 11001111b 			; granularity
	db 0 				; base high
 
; kernel space data (offset: 16 (0x10) bytes)
	dw 0FFFFh 			; limit low (Same as code)
	dw 0 				; base low
	db 0 				; base middle
	db 10010010b 			; access
	db 11001111b 			; granularity
	db 0				; base high

; User space code (offset: 24 (0x18) bytes)
	dw 0x0ffff			; limit low
	dw 0				; base low
	db 0				; base middle
	db 11111010b			; access (bits 5 and 6 are 0b11 for ring 3)
	db 11001111b			; granularity
	db 0				; base high

; User space data (offset: 32 (0x20) bytes)
	dw 0x0ffff			; limit low
	dw 0				; base low
	db 0				; base middle
	db 11110010b			; access (ring 3)
	db 11001111b			; granularity
	db 0				; base high

end_of_gdt:
toc:
	dw end_of_gdt - gdt_data - 1	; Limit (size of GDT)
	dd gdt_data			; Base of GDT

; Give the descriptor offsets names
%define NULL_DESC 0x0
%define CODE_DESC 0x8
%define DATA_DESC 0x10

%endif ;__GDT_INC_67343546FDCC56AAB872_INCLUDED__
