; vim: set filetype=asm_ca65:
    .segment "CODE"

; --- ACIA Registers ---
    ACIA_DATA     = $C010
    ACIA_STATUS   = $C011
    ACIA_COMMAND  = $C012
    ACIA_CONTROL  = $C013

    .export uart_init, put_chr, poll_chr

uart_init:
    lda #%00011111  ; 1 stop bit; WL=8; baud; 19,200
    sta ACIA_CONTROL
    lda #%00001011  ; no parity; echo off; interrupt off; DTR active low
    sta ACIA_COMMAND
    rts

put_chr:
    sta ACIA_DATA
    jsr wait_loop
    rts

poll_chr:
    clc             ; carry flag will be clear if not char ready
    lda ACIA_STATUS
    and #%00001000  ; is receiver data register full?
    beq :+          ; if not, rts (don't wait)
    lda ACIA_DATA
    sec             ; set the carry flag if we got a character
:   rts


; designed to wait the time it takes to send 10 bits at 19200 baud
; overhead = 21 cycles, loop = 160 * 5 = 800 cycles
wait_loop:
  phx
  ldx #160
: dex
  bne :-
  plx
  rts
