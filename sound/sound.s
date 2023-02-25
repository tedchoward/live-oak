; vim: set syntax=asm_ca65:

    PORTB = $6000
    PORTA = $6001

    SND_E       = %00000000
    PORTA_OFF   = %01000000

.import wait_tick

.segment "ZEROPAGE"


.segment "DATA"

.segment "CODE"


    lda #$90
    jsr snd_instr
    lda #$87
    jsr snd_instr
    lda #$07
    jsr snd_instr

    .repeat 100
        jsr wait_tick
    .endrepeat
    
    lda #$B0
    jsr snd_instr
    lda #$AF
    jsr snd_instr
    lda #$05
    jsr snd_instr

    .repeat 100
        jsr wait_tick
    .endrepeat
    
    lda #$D0
    jsr snd_instr
    lda #$C0
    jsr snd_instr
    lda #$05
    jsr snd_instr

    .repeat 100
        jsr wait_tick
    .endrepeat


    lda #$8C
    jsr snd_instr
    lda #$03
    jsr snd_instr

    .repeat 100
        jsr wait_tick
    .endrepeat

    lda #$9F
    jsr snd_instr
    lda #$BF
    jsr snd_instr
    lda #$DF
    jsr snd_instr

    rts

snd_instr:
    sta PORTB
    lda SND_E
    sta PORTA
    jsr wait_tick
    jsr wait_tick
    lda PORTA_OFF
    sta PORTA
    jsr wait_tick
    jsr wait_tick
    rts

    
.segment "RODATA"
    .feature string_escapes

