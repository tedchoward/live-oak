; vim: set filetype=asm_ca65:

	.export keyboard_init, keyboard_interrupt_handler, last_key_pressed, kb_write_ptr, kb_read_ptr, scan_keyboard, KEYBOARD_BUFFER, KEYBOARD_CHRIN

	VIA_PORTB	= $C000
	VIA_PORTA	= $C001
	VIA_DDRB	= $C002
	VIA_DDRA	= $C003
	VIA_PCR		= $C00C
	VIA_IFR		= $C00D

.zeropage

last_key_pressed:
	.byte	$00
kb_write_ptr:
	.byte	$00
kb_read_ptr:
	.byte	$00

.segment "BUFFERS"

KEYBOARD_BUFFER:
	.res	$100

.code

KEYBOARD_CHRIN:
	phx
	jsr buffer_size
	beq @no_key
	jsr buffer_read
	tax
	lda ascii_table,X
	plx
	sec
	rts
@no_key:
	plx
	clc
	rts

; PORT A => bit 7 input, rest output
; PORT B => bit 1 output
; PORT B = #$00 -- disable autoscan
; CA1 rising edge interrupt
keyboard_init:
	lda #$7f
	sta VIA_DDRA
	lda #$01
	sta VIA_DDRB
	sta VIA_PCR
	stz VIA_PORTB
	stz last_key_pressed
	stz kb_write_ptr
	stz kb_read_ptr
	rts

keyboard_interrupt_handler:
	ldx last_key_pressed
	beq @no_last_key
	jsr check_key_pressed	; is last_key_pressed currently pressed?
	bmi @return
@no_last_key:
	jsr scan_keyboard
	bpl @return
	and #$7F
	sta last_key_pressed
	jsr buffer_write

@return:
	rts


; return
;	- A: bit 7 = set if key is pressed
;	     bits 0-6 = the scan code of the key pressed
scan_keyboard:
	; stz VIA_PORTB		; disable autoscan
	ldx #$08
	stx VIA_PORTA		; select invalid key
	lda #$01
	sta VIA_IFR		; clear key interrupt

	dex
@next_col:
	; dex
	; bmi @not_found
	stx VIA_PORTA
	; bit VIA_IFR		; is a key in this column pressed?
	; beq @next_col

	txa
@next_row:
	sta VIA_PORTA
	lda VIA_PORTA
	bmi @return		; if bit 7 is set, we have our key

	clc
	adc #$10
	bpl @next_row
	dex
	bpl @next_col
@not_found:
	and #$7f		; clear bit 7 to indicate no match
@return:
	; ldx #$01
	; stx VIA_PORTB		; enable autoscan
	and #$ff		; restore flags based on value in A
	rts


; On Entry:
;	X = key to test
; On Exit:
;	A is preserved
;	Carry is preserved
;
;	X = $80 if key pressed
;	    $00 otherwise
check_key_pressed:
	stx VIA_PORTA
	ldx VIA_PORTA
	rts

; modifies
;	flags, X
.proc buffer_write
	ldx kb_write_ptr
	sta KEYBOARD_BUFFER,X
	inc kb_write_ptr
	rts
.endproc

; modifies
;	flags, A, X
.proc buffer_read
	ldx kb_read_ptr
	lda KEYBOARD_BUFFER,X
	inc kb_read_ptr
	rts
.endproc

; modifies flags, A
.proc buffer_size
	lda kb_write_ptr
	sec
	sbc kb_read_ptr
	rts
.endproc

ascii_table:
	.byte "@HPX08  "
	.byte "        "
	.byte "AIQY19  "
	.byte "        "
	.byte "BJRZ2:  "
	.byte "        "
	.byte "CKS{3+  "
	.byte "        "
	.byte "DLT|4<  "
	.byte "        "
	.byte "EMU}5=  "
	.byte "        "
	.byte "FNV~6>  "
	.byte "        "
	.byte "GOW+7?  "
