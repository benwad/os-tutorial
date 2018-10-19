;*************************************************
;	stdio.inc
;	  - Input/Output routines
;
;*************************************************

%ifndef __STDIO_INC_67343546FDCC56AAB872_INCLUDED__
%define __STDIO_INC_67343546FDCC56AAB872_INCLUDED__

;*************************************************
;	puts16 ()
;	  - Prints a null terminated string
;	DS=>SI: 0 terminated string
;*************************************************

bits 16

puts16:
	pusha			; Save registers
.loop1:
	lodsb			; Load the next byte from string from SI to AL
	or	al, al		; Does AL=0?
	jz	puts16Done	; Yep, null terminator found - bail out
	mov	ah, 0x0e	; Nope - print the character
	int	0x10		; Invoke BIOS
	jmp	.loop1
puts16Done:
	popa			; Restore registers
	ret			; We are done, return


;*************************************************
;	putch32 ()
;		- Prints a character to the screen
;	BL => Character to print
;*************************************************

bits 32

%define	VIDMEM		0xb8000		; Video memory start
%define COLS		80		; Width of screen
%define	LINES		25		; Height of screen

_CurX		db 0
_CurY		db 0
_CharAttr	db	0b00011111

putch32:
	pusha			; Save registers
	mov	edi, VIDMEM	; Get pointer to video memory

	;----------------------------------------------
	;	Get current position
	;----------------------------------------------
	xor	eax, eax	; Clear eax

	;----------------------------------------------
	;	Calculate Y pos: y * COLS * 2
	;----------------------------------------------
	mov	ecx, COLS * 2		; Bytes per line
	mov	al, BYTE [_CurY]	; Get Y pos
	mul	ecx			; Multiply y pos by COLS*2
	push	eax			; Save eax -- the multiplication

	;----------------------------------------------
	;	Now calculate X pos to add to Y pos
	;----------------------------------------------
	mov	al, BYTE [_CurX]	; Multiply _CurX by 2 because it's 2 bytes per char
	mov	cl, 2
	mul	cl
	pop	ecx			; Pop y*COLS result
	add	eax, ecx

	;----------------------------------------------
	;	Now we have the vidmem offset in eax, so just
	;	add it to the vidmem base address (stored in edi)
	;----------------------------------------------
	xor	ecx, ecx
	add	edi, eax

	;----------------------------------------------
	;	Watch for new line
	;----------------------------------------------
	cmp	bl, 0x0a		; Is it a newline character?
	je	.row			; Yes - go to next row

	;----------------------------------------------
	;	Print a character
	;----------------------------------------------
	mov	dl, bl			; Get character
	mov	dh, BYTE [_CharAttr]	; The character attribute
	mov	WORD [edi], dx		; Write to video display

	;----------------------------------------------
	;	Update next position
	;----------------------------------------------
	inc	BYTE [_CurX]		; Go to next character
	cmp	BYTE [_CurX], COLS	; Are we at the end of the line?
	je	.row			; Yep - go to next row
	jmp	.done			; Nope - Bail out

	;----------------------------------------------
	;	Go to next row
	;----------------------------------------------
.row:
	mov	BYTE [_CurX], 0		; Go back to col 0
	inc	BYTE [_CurY]		; Go to next row

	;----------------------------------------------
	;	Restore registers & return
	;----------------------------------------------
.done:
	popa				; Restore registers and return
	ret

;*************************************************
;	puts32 ()
;		- Prints a null-terminated string to the screen
;	EBX => Address of start of string
;*************************************************
puts32:
	;----------------------------------------------
	;	Store registers
	;----------------------------------------------
	pusha				; Save registers
	push	ebx			; Copy the string address
	pop	edi

.loop:
	;----------------------------------------------
	;	Get character, test for null
	;----------------------------------------------
	mov	bl, BYTE [edi]		; Get next character
	cmp	bl, 0			; Is it 0 (null terminator)?
	je	.done			; Yep - bail out

	;----------------------------------------------
	;	Print the character
	;----------------------------------------------
	call	putch32			; Nope - print it out

	;----------------------------------------------
	;	Go to next character
	;----------------------------------------------
.next:
	inc	edi			; Go to next character
	jmp	.loop

.done:
	;----------------------------------------------
	;	Update hardware cursor
	;----------------------------------------------
	; It's more efficient to update the cursor after displaying
	; the complete string because direct VGA is slow

	mov	bh, BYTE [_CurY]	; Get current position
	mov	bl, BYTE [_CurX]
	call	movCur			; Update cursor

	popa				; Restore registers


;*************************************************
;	moveCur ()
;		- Update hardware cursor
;	BH => Y pos
;	BL => X pos
;*************************************************

bits 32

movCur:
	pusha				; Save registers

	;----------------------------------------------
	;	Get current position
	;----------------------------------------------
	; Here, _CurX and _CurY are relative to the current position on screen, not in memory.
	; That is, we don't need to worry about the byte alignment we do when displaying characters,
	; So just follow the formula: location = _CurX + (_CurY * COLS)
	xor	eax, eax
	mov	ecx, COLS
	mov	al, bh			; Get Y pos
	mul	ecx			; Multiply y*COLS
	add	al, bl			; Now add x
	mov	ebx, eax

	;----------------------------------------------
	;	Set low byte index to VGA register
	;----------------------------------------------
	mov	al, 0x0f		; Cursor location low byte index
	mov	dx, 0x03d4		; Write it to the CRT index register
	out	dx, al

	mov	al, bl			; The current location is in EBX. BL contains the low byte, BH the high byte
	mov	dx, 0x03d5		; Write it to the data register
	out	dx, al			; Low byte

	;----------------------------------------------
	;	Set high byte index to VGA register
	;----------------------------------------------
	xor	eax, eax

	mov	al, 0x0e		; Cursor location high byte index
	mov	dx, 0x03d4		; Write to the CRT index register
	out	dx, al

	mov	al, bh			; The current location is in EBX. BL contains low byte, BH high byte
	mov	dx, 0x03d5		; Write it to the data register
	out	dx, al			; High byte

	popa
	ret


;*************************************************
;	clrScr32 ()
;		- Clears screen
;*************************************************
bits 32

clrScr32:
	pusha
	cld
	mov	edi, VIDMEM
	mov	cx, 2000
	mov	ah, BYTE [_CharAttr]
	mov	al, ' '
	rep	stosw

	mov	BYTE [_CurX], 0
	mov	BYTE [_CurY], 0
	popa
	ret

%endif ;__STDIO_INC_67343546FDCC56AAB872_INCLUDED__
