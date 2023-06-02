    .segment "CODE"

; --- ACIA Registers ---
    ACIA_DATA     = $4400
    ACIA_STATUS   = $4401
    ACIA_COMMAND  = $4402
    ACIA_CONTROL  = $4403

; --- Zero Page ---
    ticks     = $00  ; 4 bytes ($00 - $03)
    wait      = $04
    sbuf_eof  = $26

    .export uart_init, put_chr, poll_chr, wait_tick

uart_init:
    lda #%00011110  ; 1 stop bit; WL=8; baud; 9600
    sta ACIA_CONTROL
    lda #%00001011  ; no parity; echo off; interrupt off; DTR active low
    sta ACIA_COMMAND
    stz sbuf_eof
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

wait_tick:
    pha
    lda ticks
    sta wait
:   lda ticks
    cmp wait
    beq :-
    pla
    rts

; designed to wait the time it takes to send 10 bits at 9600 baud
; overhead = 21 cycles, loop = 204 * 5 = 1020 cycles
wait_loop:
  phx
  ldx #204
: dex
  bne :-
  plx
  rts
