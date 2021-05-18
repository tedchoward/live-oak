PORTB = $6000
PORTA = $6001
DDRB  = $6002
DDRA  = $6003

E  = %10000000
RW = %01000000
RS = %00100000

    .org $8000

reset:
    lda #%11111111  ; Set all pins on port B to output
    sta DDRB

loop:
    lda #%01010101
    sta PORTB

    lda #%10101010
    sta PORTB

    jmp loop

    .org $FFFC
    .word reset
    .word $0000
