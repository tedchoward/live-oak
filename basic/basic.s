; vim: set syntax=asm_ca65:

CHAR_BS = $08
CHAR_LF = $0a
CHAR_CR = $0d
CHAR_SPACE = $20
CHAR_PLUS = $2b
CHAR_ZERO = $30
CHAR_GT = $3e
CHAR_T = $54
;INPUT_BUFFER = $0200

.import poll_chr, put_chr

.segment "ZEROPAGE"

ptr: .word 0
output_ptr: .word 0

.segment "DATA"

INPUT_BUFFER:
    .repeat(256)
        .byte 0
    .endrepeat
OUTPUT_STACK:
    .repeat(256)
        .byte 0
    .endrepeat
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
    cmp #CHAR_ZERO  ; if the value is < '0', this is not a digit
    bcc lbl
    cmp #$3a        ; if the value is >= ':' (val > '9'), this is not a digit
    bcs lbl
    and #$0f        ; we have a valid digit, drop the hi nibble to get the value
.endscope
.endmacro

; multiplies the 16-bit number at value by 10, storing the result in value
; val * 10 == (val * 8) + (val * 2)
.macro mul16_x10
.scope
    pha
    lda REG16_A
    sta REG16_B
    lda REG16_A + 1
    sta REG16_B + 1

    ; multiply value by 8
    .repeat(3)
    asl REG16_A
    rol REG16_A + 1
    .endrepeat

    ; multiply original value by 2
    asl REG16_B
    rol REG16_B + 1

    ; add the two 16-bit values
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

.macro newline
    lda #CHAR_CR
    jsr put_chr
    lda #CHAR_LF
    jsr put_chr
.endmacro

.macro outstk_push addr
    lda addr + 1
    sta (output_ptr)
    inc16 output_ptr
    lda addr
    sta (output_ptr)
    inc16 output_ptr
.endmacro

.macro outstk_pull addr
    dec16 output_ptr
    lda (output_ptr)
    sta addr
    dec16 output_ptr
    lda(output_ptr)
    sta addr + 1
.endmacro

.proc start_cli
    set_ptr ptr, INPUT_BUFFER           ; initialize ptr to start of buffer
    set_ptr output_ptr, OUTPUT_STACK    ; initialize output_ptr

    ; print prompt
    lda #CHAR_GT
    jsr put_chr
    lda #CHAR_SPACE
    jsr put_chr

wait_for_chr:
    jsr poll_chr
    bcc wait_for_chr
    is_chr CHAR_CR, backspace
    sta (ptr)
    jsr put_chr
    lda #CHAR_LF
    jsr put_chr

    set_ptr ptr, INPUT_BUFFER    ; initialize ptr to start of buffer
    jsr evaluate
    rts
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

.proc evaluate
    jsr consume_whitespace
    is_digit error
    jsr scan_number
    jsr consume_whitespace
    is_chr CHAR_PLUS, error
    inc16 ptr               ; consume token
    jsr consume_whitespace
    is_digit error
    jsr scan_number
    jsr add16
    ; print result
    bra end
error:
    ldx $00
next_char:
    lda str_syntax_error,x
    jsr put_chr
    bne next_char
end:
    rts
.endproc

; reads numeric characters starting at ptr and converts the value into a
; 16-bit integer which is pushed to the TODO stack
.proc scan_number
    ; initialize work memory
    stz REG16_A
    stz REG16_A + 1

    is_digit end
    jsr put_chr
    sta REG16_A
next_digit:
    inc16 ptr
    is_digit end
    jsr put_chr
    mul16_x10       ; multiply REG16_A by 10
    clc
    adc REG16_A       ; add A to REG16_A
    sta REG16_A
    bcc skip_hi     ; since we're adding an 8-bit value to a 16-bit value
    inc REG16_A + 1   ; if the carry is set, we just need to increment the hi bit
skip_hi:
    bra next_digit
end:
    ; push 16-bit number at REG16_A to the proper stack
    outstk_push REG16_A
    rts
.endproc

.proc consume_whitespace
    lda (ptr)
    is_chr CHAR_SPACE, end
    inc16 ptr
    bra consume_whitespace
end:
    rts
.endproc

.proc add16
    outstk_pull REG16_A
    outstk_pull REG16_B
    clc
    lda REG16_A
    adc REG16_B
    sta REG16_A
    lda REG16_A + 1
    adc REG16_B + 1
    sta REG16_A + 1
    outstk_push REG16_A
    rts
.endproc

.segment "RODATA"

str_syntax_error:
    .byte "Syntax Error", CHAR_CR, CHAR_LF, $00
