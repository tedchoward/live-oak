; vim: set filetype=asm_ca65:

	VIA_PORTB	= $C000
	VIA_PORTA	= $C001
	VIA_DDRB	= $C002
	VIA_DDRA	= $C003
	VIA_PCR		= $C00C
	VIA_IFR		= $C00D

.zeropage

.code

; PORT A => bit 7 input, rest output
; PORT B => bit 1 output
; PORT B = #$01
; CA1 rising edge interrupt
keyboard_init:
	lda #$7f
	sta VIA_DDRA
	lda #$01
	sta VIA_DDRB
	sta VIA_PORTB
	sta VIA_PCR
	rts

; return
;	- A: bit 7 = set if key is pressed
;	     bits 0-6 = the scan code of the key pressed
scan_keyboard:
	ldx #$07
@next_col:
	txa
@next_row:
	sta VIA_PORTA
	lda VIA_PORTA
	bmi @return
	clc
	adc #$10
	cmp #$80
	bcc @next_row
	dex
	bpl @next_col
@return:
	rts

