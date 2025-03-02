; vim:set filetype=asm_ca65:

	.export parse_number

	.zeropage
ptr:	.word:	$0000
B:	.byte	$00
y_sav:	.byte	$00
current_num:
	.word $00

	.segment "BUFFERS"
	.bss
	.data
	.code

; parse the ASCII-encoded decimal number at (AX),Y
; return the 16-bit number at AX
; C=0 on success
; C=1 on error
parse_number:
	sta	ptr
	stx	ptr+1
	sty	y_sav			; save Y to compare against later
	stz	current_num
	stz	current_num + 1

@next_digit:
	lda	(ptr),y
	eor	#$30			; map 0-9
	cmp	#$0A			; is it a decimal digit?
	bcs	@notdigit		; if not, return

; We are building up a numeric value from decimal digits. Every time we add
; a new digit, we first multiply the current value by 10, then we add the value
; of the new digit.

	tax
	jsr	mul_10
	txa
	adc	current_num
	bcc	:+
	inc	current_num+1
:	iny
	bne	@next_digit		; is this right?
					; or should this be a bigger error
					; buffer overflow?
@notdigit:
; First, have we successfully processed any digits?
	cpy	y_sav
	beq	@error

	; return the 16-bit value in AX
	sta	current_num
	stx	current_num+1
	clc				; clear carry to indicate success
	rts


@error:
	sec	; set the carry bit to indicate an error
	rts


; Multiplies the 16-bit number in current_num by 10
; Stores the result in current_num
; current_num * 10
;	= current_num * 8 + current_num * 2
;	= current_num << 3 + current_num << 1
.proc mul_10
	asl	current_num
	rol	current_num+1
	lda	current_num+1
	sta	B
	lda	current_num
.repeat 2
	asl	A
	rol	B
.endrepeat
	clc
	adc	current_num
	sta	current_num
	lda	B
	adc	current_num+1
	sta	current_num+1
	rts
.endproc

