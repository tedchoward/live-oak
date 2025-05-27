; vim: set filetype=asm_ca65:

	.export keyboard_init, keyboard_interrupt_handler, last_key_pressed, scan_keyboard

	VIA_PORTB	= $C000
	VIA_PORTA	= $C001
	VIA_DDRB	= $C002
	VIA_DDRA	= $C003
	VIA_PCR		= $C00C
	VIA_IFR		= $C00D

.zeropage

last_key_pressed:
	.byte	$00

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

keyboard_interrupt_handler:
	lda VIA_IFR		; bit 0 is set if key was pressed
	lsr
	bcc @return		; if no key pressed, do nothing
	jsr scan_keyboard
	bpl @return		; bit 7 will be set if key found
	sta last_key_pressed
@return:
	rts


; return
;	- A: bit 7 = set if key is pressed
;	     bits 0-6 = the scan code of the key pressed
scan_keyboard:
	stz VIA_PORTB		; disable autoscan
	ldx #$08
	stx VIA_PORTA		; select invalid key
	lda #$01
	sta VIA_IFR		; clear key interrupt

@next_col:
	dex
	bmi @not_found
	stx VIA_PORTA
	bit VIA_IFR		; is a key in this column pressed?
	beq @next_col

	txa
@next_row:
	sta VIA_PORTA
	lda VIA_PORTA
	bmi @return		; if bit 7 is set, we have our key

	clc
	adc #$10
	bpl @next_row
@not_found:
	and #$7f		; clear bit 7 to indicate no match
@return:
	ldx #$01
	stx VIA_PORTB		; enable autoscan
	and #$ff		; restore flags based on value in A
	rts

