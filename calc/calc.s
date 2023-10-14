; vim:set filetype=asm_ca65:

	;.import poll_chr, put_chr, c_out
	.segment "CODE"

	.export main, mul, calc_add

; --- sys calls
	poll_chr	= $D012
	put_chr		= $D00B
	c_out		= $D15C

; --- Zero Page ---
	L		= $98
	H		= $99
	YSAV		= $9A
	MUL_RES		= $9B	; 3 bytes ($2B - $2D) same as B, C, D
	B		= $9B
	C		= $9C
	D		= $9D
	MPR		= $9E
	RSP		= $9F
	OSP		= $A0
	FLAGS		= $A1		; bit 0 = operator, bit 1 = negate

; --- Variables ---
	input_buffer	= $8100
	result_stack	= $8000
	operator_stack	= $8200

; --- Constants ---
	CTRLC		= $03
	BS		= $08
	CR		= $0D
	PROMPT		= $3E		; '>' character
	EXIT_VEC	= $D027

main:
	ldx	#$FF
	stx	RSP			; initialize result_stack pointer
	stx	OSP			; and operator_stack pointer
	lda	#$01
	sta	FLAGS			; initialize flags to %00000001
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
	beq	pop_opstk
	cmp	#'+'
	beq	operator
	cmp	#'-'
	beq	operator
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
	sta	MPR
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

	; once the value has been fully loaded, if the negate flag is set,
	; we need to convert the number into it's twos-complement form
	bbr1	FLAGS, notdigit
	rmb1	FLAGS
	lda	L
	eor	#$FF
	clc
	adc	#$01
	sta	L
	lda	H
	eor	#$FF
	adc	#$00
	sta	H

notdigit:
	cpy	YSAV
	beq	getline		; if no digits found, start over

	; if we are processing a digit, clear the operator flag
	rmb0	FLAGS

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

operator:
	bbr0	FLAGS, process_operator
	; if the operator flag was set, this must be a unary
	cmp	#'-'
	bne	ignore
	smb1	FLAGS
ignore:
	bra	nextitem

process_operator:
	smb0	FLAGS
	ldx	OSP
	sta	operator_stack,x
	dex
	stx	OSP
	iny
	bra	nextitem

.proc pop_opstk
	ldx	OSP
loop:
	cpx	#$FF
	beq	end
	inx
	lda	operator_stack,x
	cmp	#'+'
	bne	sub
	jsr	calc_add
	bra	loop
sub:
	cmp	#'-'
	bne	loop
	jsr	calc_sub
	bra	loop
end:
	stx	OSP
	jsr	print_num
	jmp	getline
.endproc

	jmp	EXIT_VEC

; execute both a uart put_char and pinky c_out
; aka output character to both serial and display
echo:
	jsr put_chr
	jsr c_out
	rts

; pops the 16-bit number off the top of the stack and echos it as a
; decimal value
.proc print_num
	; pull the 16-bit number off the stack. High Byte -> A, Low Byte -> B
	ldx	RSP
	inx
	lda	result_stack,x
	sta	B
	inx
	lda	result_stack,x
	stx	RSP

	; handle-negative numbers
	bpl	not_negative
	tay
	lda	#'-'		; if the value is negative, output a '-',
	jsr	echo		; then convert the number to it's
	lda	B		; twos-complement value and output
	eor	#$FF
	clc
	adc	#$01
	sta	B
	tya
	eor	#$FF
	adc	#$00

not_negative:
	ldx	#2
	stx	C

	ldx	#8
	ldy	#$26
next_digit:
	sty	D
	lsr
	ror	B
compare:
	rol	B
	rol
	tay
	bcs	subtract
	sec
	lda	B
	sbc	tbl,x
	tya
	sbc	tbl+1,x
	tya
	bcc	output_digit
subtract:
	lda	B
	sbc	tbl,x
	sta	B
	tya
	sbc	tbl+1,x
	sec
output_digit:
	rol	D
	bcc	compare
	tay
	lda	D
	cmp	#$30
	beq	digit_is_zero
	stx	C
	bra	echo_digit
digit_is_zero:
	cpx	C
	bcs	skip_echo
echo_digit:
	jsr	echo
skip_echo:
	tya
	ldy	#$13
	dex
	dex
	bpl	next_digit
	rts
tbl:	.word	$4000, $5000, $6400, $7D00, $9C40
.endproc


; Multiplies the 16-bit number in L,H with the 8-bit number in A
; The 24-bit result is stored in MUL_RES
.proc mul
	stz	MUL_RES
	stz	MUL_RES+1
	stz	MUL_RES+2
	ldx	#8
loop:
	lsr	MPR
	bcc	no_add
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
	dex
	bne	loop
	rts
.endproc

; adds the two 16-bit numbers at the top of the stack
; places the result on the stack
.proc calc_add
	phx
	ldx	RSP
	inx
	lda	result_stack,x
	sta	MUL_RES
	inx
	lda	result_stack,x
	sta	MUL_RES+1
	clc
	inx
	lda	result_stack,x
	adc	MUL_RES
	sta	MUL_RES
	inx
	lda	result_stack,x
	adc	MUL_RES+1
	sta	result_stack,x
	dex
	lda	MUL_RES
	sta	result_stack,x
	dex
	stx	RSP
	plx
	rts
.endproc

; subtracts the two 16-bit numbers at the top of the stack
; places the resut on the stack
.proc calc_sub
	phx
	ldx	RSP
	inx
	lda	result_stack,x
	sta	MUL_RES
	inx
	lda	result_stack,x
	sta	MUL_RES+1
	inx
	lda	result_stack,x
	sec
	sbc	MUL_RES
	sta	MUL_RES
	inx
	lda	result_stack,x
	sbc	MUL_RES+1
	sta	result_stack,x
	dex
	lda	MUL_RES
	sta	result_stack,x
	dex
	stx	RSP
	plx
	rts
.endproc
