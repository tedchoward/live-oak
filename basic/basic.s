CHAR_BS = $08
CHAR_CR = $0d
CHAR_SPACE = $20
CHAR_ZERO = $30
CHAR_GT = $3e
INPUT_BUFFER = $0200

.import poll_chr, put_chr

.segment "ZEROPAGE"

ptr: .word 0

.segment "DATA"

REG16_A: .word 0
REG16_B: .word 0

.segment "CODE"

; store a 16-bit address in a zero-page pointer
.macro set_ptr ptr_ref, value
    lda #<value
    sta ptr_ref
    lda #>value
    sta ptr_ref + 1
.endmacro

; continue executing if the character in A matches chr, otherwise jump to lbl
.macro is_chr chr, lbl
    cmp #chr
    bne lbl
.endmacro

; if the character at ptr is a digit (0-9), store the numeric value in A
; othwerise jump to lbl
.macro is_digit lbl
.scope
    lda (ptr)
    sec
    sbc #CHAR_ZERO
    cmp #$0a        ; if the value in A is > 10, this is not a digit
    bcs lbl         ; acc > 10
.endscope
.endmacro

; multiplies the 16-bit number at value by 10, storing the result in value
.macro mul16_x10
.scope
    pha
    lda REG16_A
    sta REG16_B
    lda REG16_A + 1
    sta REG16_B + 1

    .repeat(3)
    clc
    asl REG16_A
    asl REG16_A + 1
    .endrepeat

    clc
    asl REG16_B
    asl scan_number + 1

    clc
    lda REG16_B
    adc REG16_A
    sta REG16_A
    lda REG16_B + 1
    adc REG16_A + 1
    sta REG16_A + 1
    pla
.endscope
.endmacro

; increments a 16-bit number at lbl
.macro inc16 lbl
.scope
    inc lbl
    bne skip
    inc lbl+1
skip:
.endscope
.endmacro

; decrements a 16-bit number at lbl
.macro dec16 lbl
.scope
    lda lbl
    bne skip
    dec lbl+1
skip:
    dec lbl
.endscope
.endmacro

.proc start_cli
    set_ptr ptr, INPUT_BUFFER    ; initialize ptr to start of buffer

    ; print prompt
    lda #CHAR_GT
    jsr put_chr
    lda #CHAR_SPACE
    jsr put_chr

wait_for_chr:
    jsr poll_chr
    bcc wait_for_chr
    is_chr CHAR_CR, backspace
    jsr put_chr

    set_ptr ptr, INPUT_BUFFER    ; initialize ptr to start of buffer
    jsr scan_number
    bra start_cli
backspace:
    is_chr CHAR_BS, buffer_ch
    dec16 ptr
    bra echo
buffer_ch:
    sta (ptr)
    inc16 ptr
echo:
    jsr put_chr
    bra wait_for_chr
.endproc

; reads numeric characters starting at ptr and converts the value into a
; 16-bit integer which is pushed to the TODO stack
.proc scan_number
    ; initialize work memory
    stz REG16_A
    stz REG16_A + 1

    is_digit end
    sta REG16_A
    inc16 ptr
next_digit:
    is_digit end
    mul16_x10       ; multiply REG16_A by 10
    clc
    adc REG16_A       ; add A to REG16_A
    sta REG16_A
    bcc skip_hi     ; since we're adding an 8-bit value to a 16-bit value
    inc REG16_A + 1   ; if the carry is set, we just need to increment the hi bit
skip_hi:
    bra next_digit
end:
    ; TODO push 16-bit number at REG16_A to the proper stack
    rts
.endproc

.segment "RODATA"
