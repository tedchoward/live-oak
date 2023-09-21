; vim:set filetype=asm_ca65:

	.import poll_chr, put_chr, c_out
	.segment "CODE"

; --- Zero Page ---
	L		= $28
	H		= $29
	YSAV		= $2A
	MUL_RES		= $2B	; 3 bytes ($2B - $2D)
	RSP		= $2E

; --- Variables ---
	input_buffer	= $0200
	result_stack	= $8000


; --- Constants ---
	CTRLC		= $03
	BS		= $08
	CR		= $0D
	PROMPT		= $3E		; '>' character
	EXIT_VEC	= $D027

main:
	ldx	#$FF
	stx	RSP			; initialize result_stack pointer
	lda	#CTRLC
notcr:
	cmp	#BS
	beq	backspace
	cmp	#CTRLC
	beq	getline
	iny
	bpl	nextchar
getline:
	lda	#CR
	jsr	echo
	lda	#PROMPT
	jsr	echo

	ldy	#$01
backspace:
	dey
	bmi	getline

nextchar:
	jsr	poll_chr
	bcc	nextchar
	sta	input_buffer,y
	jsr	echo
	cmp	#CR
	bne	notcr

; time to parse
	ldy	#$FF
	lda	#$00
	ldx	#$00

skip:
	iny

nextitem:
	lda	input_buffer,y
	cmp	#CR
	beq	getline
	cmp	#$27			; ignore everything below "'"
	bcc	skip
	stz	L
	stz	H
	sty	YSAV

nextdec:
	lda	input_buffer,y
	eor	#$30			; map digits 0-9
	cmp	#$0A			; is it a decimal digit?
	bcs	notdigit		; if not, start over

; We are building up a numeric value from decimal digits. Every time we add
; a new digit, we first multiply the current value by 10, then we add the value
; of the new digit.

	; L,H = L,H * 10
	pha
	lda	#10
	jsr	mul
	lda	MUL_RES
	sta	L
	lda	MUL_RES+1
	sta	H
	pla

	; L,H = A,0 + L,H
	adc	L
	sta	L
	lda	H
	adc	#$00
	sta	H

	iny
	bne	nextdec

notdigit:
	cpy	YSAV
	beq	getline		; if no digits found, start over

	; now we push to the stack
	ldx	RSP
	lda	H
	sta	result_stack,x
	dex
	lda	L
	sta	result_stack,x
	dex
	stx	RSP

	jmp	nextitem


	jmp	EXIT_VEC

; execute both a uart put_char and pinky c_out
; aka output character to both serial and display
echo:
	jsr put_chr
	jsr c_out
	rts

; Multiplies the 16-bit number in L,H with the 8-bit number in A
; The 24-bit result is stored in MUL_RES
.proc mul
	stz	MUL_RES
	stz	MUL_RES+1
	stz	MUL_RES+2
	ldx	#8
loop:
	lsr	A
	bcc	no_add
	tay
	lda	MUL_RES+1
	clc
	adc	L
	sta	MUL_RES+1
	lda	MUL_RES+2
	adc	H
	sta	MUL_RES+2
no_add:
	lsr	MUL_RES+2
	ror	MUL_RES+1
	ror	MUL_RES
	tya
	dex
	bne	loop
	rts
.endproc
