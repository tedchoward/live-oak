; Routines to control the VDP "Pinky"

	CURSOR_ROW	= $05
	CURSOR_COL	= $06
	CURRENT_ROW_ADR	= $07

	VRAM_ADDR_HI	= $C020
	VRAM_ADDR_LO	= $C024
	VRAM_DATA	= $C028

	MAX_COL		= $27

	LINE_BUFFER	= $0400

	.export init_pinky, c_out, cr_out
	.segment "CODE"

.proc init_pinky
	jsr	clear_screen
	stz	CURSOR_COL
	stz	CURSOR_ROW
	stz	VRAM_ADDR_LO
	stz	VRAM_ADDR_HI
	stz	CURRENT_ROW_ADR
	stz	CURRENT_ROW_ADR + 1

.endproc

; Blanks the screen by writing ASCII $20 (' ') characters to every location in
; VRAM.
.proc clear_screen
	pha
	phx
	phy
	stz	VRAM_ADDR_HI
	stz	VRAM_ADDR_LO
	lda	#$20		; ASCII ' '
	ldy	#$1e		; 30 rows per screen
row:	ldx	#$28		; 40 cols per row
col:	sta	VRAM_DATA
	dex
	bne	col
	dey
	bne	row
	ply
	plx
	pla
	rts
.endproc

; Print a carriage return to the screen
.proc cr_out
	lda	#$0d
	; Fall through to c_out
.endproc

; Prints a character (store in A) to the screen
.proc c_out
	pha
	phx
	cmp	#$20
	bcs	printable_char
; control characters
	cmp	#$0d			; carriage return
	beq	new_row
	cmp	#$08			; backspace
	bne	end
	dec	CURSOR_COL
	bpl	end			; skip to the end unless we underflowed
	lda	#MAX_COL
	sta 	CURSOR_COL
	sec
	lda	CURRENT_ROW_ADR
	sbc	#40
	sta	CURRENT_ROW_ADR
	lda	CURRENT_ROW_ADR + 1
	sbc	#00
	sta	CURRENT_ROW_ADR + 1
	bra	end

printable_char:
	tax
	clc
	lda	CURRENT_ROW_ADR
	adc	CURSOR_COL
	sta	VRAM_ADDR_LO
	lda	CURRENT_ROW_ADR + 1
	adc	#$00
	sta	VRAM_ADDR_HI
	txa
	sta	VRAM_DATA

	; Increment cursor
	inc	CURSOR_COL
	lda	CURSOR_COL
	cmp	#MAX_COL + 1		; Do we need to drop a row?
	bcc	end			; No, jump to end
new_row:
	stz	CURSOR_COL
	lda	CURSOR_ROW
	cmp	#29			; row 29 is the bottom row
	bcc	next_row
	jsr	scroll
	bra	end
next_row:
	inc	CURSOR_ROW
	clc
	lda	CURRENT_ROW_ADR
	adc	#40
	sta	CURRENT_ROW_ADR
	bcc	end
	inc	CURRENT_ROW_ADR + 1
end:
	plx
	pla
	rts
.endproc

.proc scroll
	pha
	phx
	phy
	lda	#MAX_COL + 1
	sta	VRAM_ADDR_LO
	stz	VRAM_ADDR_HI
	ldx	#$01
copy_row:
	ldy	#$00
copy_next_char:
	lda	VRAM_DATA
	sta	LINE_BUFFER,y
	iny
	cpy	#MAX_COL + 1
	bne	copy_next_char
	; Set VRAM_ADDR to start of previous row
	sec
	lda	VRAM_ADDR_LO
	sbc	#80
	sta	VRAM_ADDR_LO
	lda	VRAM_ADDR_HI
	sbc	#0
	sta	VRAM_ADDR_HI
	ldy	#$00
paste_next_char:
	lda	LINE_BUFFER,y
	sta	VRAM_DATA
	iny
	cpy	#MAX_COL + 1
	bne	paste_next_char

	; set VRAM_ADDR to start or curRow + 2
	; and repeat
	inx
	cpx	#31
	bcs	end
	clc
	lda	VRAM_ADDR_LO
	adc	#40
	sta	VRAM_ADDR_LO
	lda	VRAM_ADDR_HI
	adc	#00
	sta	VRAM_ADDR_HI
	bra	copy_row
end:
	; blank out the last line
	ldy	#40
	lda	#$20
blank:
	sta	VRAM_DATA
	dey
	bne	blank

	ply
	plx
	pla
	rts
.endproc
