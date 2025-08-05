; vim: set filetype=asm_ca65:
	.import poll_chr, put_chr, uart_init, init_pinky, c_out, xmodem_receive, irq_init, irq_brk, keyboard_init

	.export echo, escape

	.zeropage

XAML:	.byte $00	; Last opened location low
XAMH:	.byte $00	; Last opened location high
STL:	.byte $00	; Store address low
STH:	.byte $00	; Store address high
L:	.byte $00	; Hex value parsing low
H:	.byte $00	; Hex value parsing high
YSAV:	.byte $00	; Used to see if hex value is given
MODE:	.byte $00	; $00=XAM, $7F=STOR, $AE=BLOCK XAM

	.segment "BUFFERS"

IN:	.res $100	; Input buffer

	.code

; --- Constants ---
	BS     = $08	; backspace key
	CR     = $0d	; carriage return
	LF     = $0a	; carriage return
	ESC    = $1b	; ESC key
	PROMPT = $5c	; Prompt character ("\")

reset:
	cld
	lda	#$02
	sta	$00		; select RAM bank 2 (0 and 1 mirror low memory)
	jsr	uart_init
	jsr	init_pinky
	jsr	irq_init
	jsr	keyboard_init
	cli			; enable interrupts
	lda	#ESC		; cause an auto ESC

; --- GETLINE process ---
notcr:
	cmp	#BS
	beq	backspace
	cmp	#ESC
	beq	escape
	iny			; advance text index
	bpl	nextchar	; auto ESC if line longer than 127

escape:
	lda	#PROMPT
	jsr	echo

getline:
	lda	#CR
	jsr	echo

	ldy	#$01
backspace:
	dey
	bmi	getline		; oops, line is empty, re-init

nextchar:
	jsr	poll_chr
	bcc	nextchar
	sta	IN,y
	jsr	echo
	cmp	#CR
	bne	notcr

; Line received, time to parse

	ldy	#$ff		; reset text idex
	lda	#$00		; default mode is XAM
	tax			; X=0

setblock:
	asl
setstor:
	asl			; leaves $7b if setting STOR mode
	sta	MODE		; $00 = XAM, $74 = STOR, $B8 = BLOK XAM.

blskip:
	iny			; advance text index

nextitem:
	lda	IN,y		; get character
	cmp	#CR
	beq	getline		; we're done if it's a CR
	cmp	#'.'
	bcc	blskip		; ignore everything below "."!
	beq	setblock		; set BLOCK XAM mode ("." = $AE)
	cmp	#':'
	beq	setstor		; set STOR mode! $ba will become $7b
	cmp	#'G'
	beq	run		; run the program, forget the rest
	cmp	#'R'
	beq	read		; read data via xmodem protocol
	stx	L		; clear input value (X=0)
	stx	H
	sty	YSAV		; save Y for comparison

; time to parse a hex value
nexthex:
	lda	IN,y		; get character for hex test
	eor	#$30		; map digits 0-9
	cmp	#$0a		; is it a decimal digit
	bcc	dig
	adc	#$88		; map letter "A"-"F" to $fa-$ff
	cmp	#$fa		; hex letter?
	bcc	nothex

dig:
	asl
	asl			; hex digit to msd of a
	asl
	asl

	ldx	#$04		; shift count
hexshift:
	asl			; hex digit left, msb to carry
	rol	L		; rotate into LSD
	rol	H		; rotate into MSD's
	dex
	bne	hexshift
	iny
	bne	nexthex

nothex:
	cpy	YSAV		; was at least 1 hex digit found?
	beq	escape		; no? ignore all, start over

	bit	MODE		; test MODE byte
	bvc	notstor		; B6=0 is STOR, 1 is XAM, or BLOCK XAM

; STOR mode, save LSD of new hex byte

	lda	L		; LSD's of hex data
	sta	(STL,x)		; Store current 'store index'(X=0)
	inc	STL		; increment store index
	bne	nextitem
	inc	STH		; if carry, add to STH
tonextitem:
	jmp	nextitem	; get next command item

; --- RUN user's program for last opened location ---

run:
	jmp	(XAML)		; run user's program

; --- READ data via XMODEM protocol to last opened location ---
read:
	lda	XAML		; set the DATA_DESTINATION to the last location
	sta	$17		; and call xmodem_receive
	lda	XAMH
	sta	$18
	jsr	xmodem_receive
	bra	nextitem

; --- Not in store mode ---

notstor:
	bmi	xamnext		; B7 = 0 for XAM, 1 for BLOCK XAM

; --- XAM mode ---
	ldx	#2		; Copy 2 bytes
setadr:	lda	L-1,x		; copy hex data
	sta	STL-1,x		;   to 'store index'
	sta	XAML-1,x	;    and to 'XAM index'
	dex			; next of 2 bytes
	bne	setadr

; Print address and data from this address, fall through next BNE

nxtprnt:
	bne	prdata		; NE means no address to print
	lda	#CR		; print CR first
	jsr	echo
	lda	XAMH		; output high-order byte of address
	jsr	prbyte
	lda	XAML		; output low-order byte of address
	jsr	prbyte
	lda	#':'
	jsr	echo

prdata:
	lda	#' '	; Print space
	jsr	echo
	lda	(XAML,x)	; get data from address (X=0)
	jsr	prbyte
xamnext:
	stx	MODE		; 0 -> MODE (XAM mode)
	lda	XAML		; see if there's more to print
	cmp	L
	lda	XAMH
	sbc	H
	bcs	tonextitem	; no more data to output

	inc	XAML		; increment "examine index"
	bne	mod8chk
	inc	XAMH

mod8chk:
	lda	XAML		; if address MOD 8 = 0, start new line
	and	#$07
	bpl	nxtprnt		; always taken

; --- Subroutine to print a byte in A in hex form (destructive) ---

prbyte:
	pha			; save A for LSD
	lsr
	lsr
	lsr
	lsr
	jsr	prhex		; output hex digit
	pla			; restore A

; fall through to print hex routine

prhex:
	and	#$0f		; mask LSD for hex print
	ora	#'0'		; add "0"
	cmp	#$3a		; is it 0-9?
	bcc	echo
	adc	#$06		; add offset for letter A-F

; fall through to print routine

echo:
	pha
	jsr	put_chr
	jsr	c_out
	pla
	rts

; --- Vectors ---
	.segment "VECTORS"

	.word	$0F00		; NMI
	.word	reset
	.word	irq_brk		; IRQ
