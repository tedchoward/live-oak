; vim: set syntax=asm_ca65:

; --- UART Hello ---

    .segment "CODE"

; --- VIA Registers ---
    PORTB = $6000
    PORTA = $6001
    DDRB  = $6002
    DDRA  = $6003
    T1CL  = $6004
    T1CH  = $6005
    ACR   = $600B
    IFR   = $600D
    IER   = $600E

; --- LCD Control Bits ---
    ; PORTA
    LCD_E  = %11000000  ; LCD is active high
    SND_E  = %00000000  ; SND is active low
    ; PORTB
    RW = %00001000
    RS = %00000100


    PORTA_OFF = %01000000

; --- Zero Page ---
    ticks     = $00  ; 4 bytes ($00 - $03)
    pc_reg_hi = $05
    pc_reg_lo = $06
    s_reg     = $07
    a_reg     = $08
    x_reg     = $09
    y_reg     = $0A
    sp_reg    = $0B

    buffer    = $0C  ; 22 bytes ($0C - $23)
    hi_hex    = $24
    lo_hex    = $25
    sbuf_eof  = $26
    str_vec   = $27 ; 2 bytes ($27 - $28)
    start_adr = $29 ; 2 bytes ($29 - $2A)
    length    = $2B

    load_ptr  = $3A ; 2 bytes ($3A - $3B) for target load address

    SERIAL_BUFFER = $0200

    STRING_BUFFER = $0300

    prompt_ch = $AF
    CR = $0d
    LF = $0a


    .import xmodem, poll_chr, put_chr, uart_init, wait_tick

reset:
    ldx #$FF            ; initialize the stack pointer
    txs

    stz SERIAL_BUFFER   ; initialize serial buffer
    stz STRING_BUFFER   ; initialize string buffer

    jsr uart_init
    jsr timer_init
    jsr via_init
    jsr snd_init
    ; jsr lcd_init

    ; set some values into memory for testing
    lda #$01
    sta $3000
    inc
    sta $3001
    inc
    sta $3002
    inc
    sta $3003
    inc
    sta $3004
    inc
    sta $3005
    inc
    sta $3006
    inc
    sta $3007

    ; set some values in the registers for testing
    lda #$10
    ldx #$5A
    ldy #$B7

    ; print the welcome message
    lda #<welcome
    sta str_vec
    lda #>welcome
    sta str_vec + 1
    jsr print_str
    brk             ; trigger a break to grab the processor state

    ; print the prompt
print_prompt:
    stz sbuf_eof
    lda #prompt_ch  ; '»'
    jsr put_chr
    lda #' '
    jsr put_chr

loop:
    jsr poll_chr  ; read character from uart
    bcc loop      ; if a character was read,
    ; pha
    ; sta hi_hex
    ; sta lo_hex
    ; jsr convert_to_hex
    ; lda hi_hex
    ; jsr print_ch  ; print the character to LCD
    ; lda lo_hex
    ; jsr print_ch  ; print the character to LCD
    ; lda #$20      ; ' ' character
    ; jsr print_ch  ; print the character to LCD
    ; pla
    cmp #$03      ; it it CTRL-C ?
    bne case_cr
    brk
case_cr:
    cmp #$0D      ; is it a '\r'
    bne buffer_ch
    jmp execute_stmt

buffer_ch:
    ldx sbuf_eof
    cmp #$08                ; backspace
    bne store_ch
    dec sbuf_eof
    bra :+
store_ch:
    sta SERIAL_BUFFER,x
    inc sbuf_eof
:   jsr put_chr
    jmp loop

; Prints a null terminated string to the UART
; String location should be stored in vector str_vec
print_str:
    phy
    pha
    ldy #$00
:   lda (str_vec),y
    beq :+
    jsr put_chr   ; send the character to the UART
    iny
    jmp :-
:   pla
    ply
    rts

execute_stmt:
    lda #CR
    jsr put_chr
    lda #LF
    jsr put_chr

    ldx sbuf_eof            ; null-terminate `SERIAL_BUFFER`
    stz SERIAL_BUFFER,x     ; so we can use `print_str`

    ldx #0                  ; if the buffer is empty,
    cpx sbuf_eof            ; do nothing and print another prompt
    beq print_prompt

    lda SERIAL_BUFFER,x     ; get the first character
    cmp #'r'
    bne print_mem          ; if not "r" skip to next command

    inx
    lda SERIAL_BUFFER,x     ; get the second character
    bne print_buf          ; if there's anything after the "r", this is
                            ; not the print_registers command
    jsr print_registers
    jmp print_prompt
print_mem:
    cmp #'m'              ; syntax: `m <address> [<length>]`
    bne write_mem        ; if not "m" skip to next command
    ; parse arguments
    jsr parse_args_m
    bcs print_buf
    jsr print_memory
    jmp print_prompt
write_mem:
    cmp #'w'              ; syntax: `w <address> <byte>[<byte>*]`
    bne go_to        ; if not "w", skip to next command
    ; parse arguments
    jsr parse_args_w
    bcs print_buf
    ; start writing memory
    inx
    lda SERIAL_BUFFER,x   ; load high nibble
write_byte:
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x   ; load low nibble
    sta lo_hex
    jsr from_hex
    sta (start_adr)       ; write the byte to memory
    inc start_adr         ; increment the starting address
    bne :+
    inc start_adr + 1     ; increment the high byte when necessary
:   inx
    lda SERIAL_BUFFER,x   ; load high nibble
    bne write_byte
    jmp print_prompt
go_to:
    cmp #'g'
    bne go_sub
    jsr parse_args_g
    jmp goto
go_sub:
    cmp #'j'
    bne load_xmodem
    jsr parse_args_g
    ldx sp_reg              ; restore the stack pointer
    txs
    jsr gt_2                ; same as goto command, but return here
    sty y_reg               ; save the y register
    stx x_reg               ; save the x register
    sta a_reg               ; save the a register
    php                     ; push the status register the stack
    pla                     ; pull the status register
    sta s_reg               ; save the status register
    jsr print_registers
    jmp print_prompt
load_xmodem:
    cmp #'l'
    bne print_buf
    jsr parse_args_l
    jsr xmodem
    jmp print_prompt
print_buf:
    lda #<SERIAL_BUFFER
    sta str_vec
    lda #>SERIAL_BUFFER
    sta str_vec + 1
    jsr print_str

    lda #$0D              ; '/r'
    jsr put_chr
    lda #$0A              ; '/n'
    jsr put_chr

parse_args_m:
    ; parse arguments
    inx
    lda SERIAL_BUFFER,x
    cmp #' '
    sec
    bne pam_end
    inx
    lda SERIAL_BUFFER,x
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x
    sta lo_hex
    jsr from_hex
    sta start_adr+1
    inx
    lda SERIAL_BUFFER,x
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x
    sta lo_hex
    jsr from_hex
    sta start_adr
    inx
    lda SERIAL_BUFFER,x
    sec
    beq pam_end
    cmp #' '
    sec
    bne pam_end
    inx
    lda SERIAL_BUFFER,x
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x
    sta lo_hex
    jsr from_hex
    sta length
    clc
pam_end:
   rts

parse_args_w:
    ; parse arguments
    inx
    lda SERIAL_BUFFER,x
    cmp #' '              ; chomp " "
    sec
    bne paw_end
    inx
    lda SERIAL_BUFFER,x   ; load high nibble
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x   ; load low nibble
    sta lo_hex
    jsr from_hex
    sta start_adr+1       ; store high byte of start address
    inx
    lda SERIAL_BUFFER,x   ; load high nibble
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x   ; load low nibble
    sta lo_hex
    jsr from_hex
    sta start_adr         ; store low byte of start address
    inx
    lda SERIAL_BUFFER,x
    cmp #' '
    sec
    bne paw_end
    clc
paw_end:
    rts

parse_args_g:
    ; parse arguments
    inx
    lda SERIAL_BUFFER,x
    cmp #' '              ; chomp " "
    sec
    bne pag_end
    inx
    lda SERIAL_BUFFER,x   ; load high nibble
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x   ; load low nibble
    sta lo_hex
    jsr from_hex
    sta start_adr+1       ; store high byte of start address
    inx
    lda SERIAL_BUFFER,x   ; load high nibble
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x   ; load low nibble
    sta lo_hex
    jsr from_hex
    sta start_adr         ; store low byte of start address
    clc
pag_end:
    rts

parse_args_l:
    inx
    lda SERIAL_BUFFER,x
    cmp #' '                ; chomp " "
    sec
    bne pal_end
    inx
    lda SERIAL_BUFFER,x     ; load high nibble
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x     ; load low nibble
    sta lo_hex
    jsr from_hex
    sta load_ptr+1               ; store high byte of load address
    inx
    lda SERIAL_BUFFER,x     ; load high nibble
    sta hi_hex
    inx
    lda SERIAL_BUFFER,x     ; load low nibble
    sta lo_hex
    jsr from_hex
    sta load_ptr                 ; store low byte of load address
    clc
pal_end:
    rts

; debug:
;     pha
;     lda #<debug_text
;     sta str_vec
;     lda #>debug_text
;     sta str_vec + 1
;     jsr print_str
;     pla
;     rts

print_registers:
    lda #<print_reg_msg
    sta str_vec
    lda #>print_reg_msg
    sta str_vec + 1
    jsr print_str

    lda pc_reg_hi       ; print high-bit of PC
    jsr put_hex

    ldy #$01
:   lda pc_reg_hi,y     ; starting with low-bit of PC
    jsr put_hex         ; loop through the rest of the registers
    lda #' '            ; print 1-byte value followed by a space
    jsr put_chr
    iny
    cpy #$07            ; there are 5 registers to print
    bcc :-
    lda #CR
    jsr put_chr
    lda #LF
    jsr put_chr
    rts

; prints `length` (8-bits) bytes starting at `start_adr` (16-bits)

put_hex:
    sta hi_hex
    sta lo_hex
    jsr convert_to_hex
    lda hi_hex
    jsr put_chr
    lda lo_hex
    jsr put_chr
    rts

print_ascii:
    lda #':'
    jsr put_chr
    lda #' '
    jsr put_chr

    stz STRING_BUFFER,x

    lda #<STRING_BUFFER
    sta str_vec
    lda #>STRING_BUFFER
    sta str_vec + 1
    jsr print_str
    rts


goto:
    ldx sp_reg              ; restore the stack pointer
    txs
gt_2:
    lda start_adr+1         ; push the high-byte of the goto address to the
    pha                     ; stack. (RTI will think this is the value of PC)
    lda start_adr
    pha
    sei                     ; disable interrupts
    lda s_reg               ; restore the status register (RTI will set this)
    pha
    lda a_reg               ; restore the a register
    ldx x_reg               ; restore the x register
    ldy y_reg               ; restore the y register
    rti                     ; restore s_reg and set PC to new address


print_memory:
    phy
    pha
    ldy #$00

    ; add the current index to the start address
    ; this is used for printing the start address of each line
prt_line:
    tya
    and #$F8
    sta a_reg
    cpy a_reg
    bne prt_byte

    lda STRING_BUFFER
    beq start_ln
    jsr print_ascii

start_ln:
    ldx #$00
    lda #CR
    jsr put_chr
    lda #LF
    jsr put_chr
    clc
    tya
    adc start_adr
    pha

    lda #$00
    adc start_adr+1

    sta hi_hex
    sta lo_hex
    jsr convert_to_hex
    lda hi_hex
    jsr put_chr
    lda lo_hex
    jsr put_chr

    pla
    sta hi_hex
    sta lo_hex
    jsr convert_to_hex
    lda hi_hex
    jsr put_chr
    lda lo_hex
    jsr put_chr
    lda #':'
    jsr put_chr
    lda #' '
    jsr put_chr

prt_byte:
    lda (start_adr),y
    sta hi_hex
    sta lo_hex
    jsr clean_byte
    sta STRING_BUFFER,x
    jsr convert_to_hex
    lda hi_hex
    jsr put_chr
    lda lo_hex
    jsr put_chr
    lda #$20            ; ' ' character
    jsr put_chr
    iny
    inx
    cpy length
    bne prt_line

pad:
    cpx #$08
    beq :+
    lda #' '
    jsr put_chr
    jsr put_chr
    jsr put_chr
    inx
    jmp pad

:   jsr print_ascii
    stz STRING_BUFFER

    lda #CR
    jsr put_chr
    lda #LF
    jsr put_chr
    pla
    ply
    rts


convert_to_hex:
    phy
    pha
    lsr hi_hex
    lsr hi_hex
    lsr hi_hex
    lsr hi_hex
    ldy hi_hex
    lda hex_lookup,y
    sta hi_hex
    lda lo_hex
    and #$0F
    tay
    lda hex_lookup,y
    sta lo_hex
    pla
    ply
    rts


; convert the 2-digit hexadecimal string stored in hi_hex and lo_hex to it's
; value. Stores the result in A
from_hex:
    lda hi_hex
    jsr from_hex_digit
    asl
    asl
    asl
    asl
    sta hi_hex
    lda lo_hex
    jsr from_hex_digit
    ora hi_hex
    rts

; Convert the value in A from a hexadecimal digit string to it's value
from_hex_digit:
    sta a_reg
    and #$DF      ; clear bit 5. Will make an lowercase letter uppercase
    sec
    sbc #$41      ; 'A'
    bcs af       ; if >= 0 goto .af
    sec           ; else try '0'-'9'
    lda a_reg
    sbc #$30      ; '0'
    bcc err      ; if < 0 goto err
    clc
    jmp end
af:
    clc
    adc #$0A
    cmp #$10      ; if <= $10 we have a valid byte
    bcc end      ; else not A-F
err:
    sec           ; set the carry flag to indicate an error
end:
    rts

; If the value in A is a printable ASCII character, do nothing. Otherwise
;   replace the value in A with "."
clean_byte:
    sec
    cmp #$20      ; first non-control character
    bcs not_ctrl
    lda #'.'
not_ctrl:  sec
    cmp #$7F
    bne return
    lda #'.'
return:
    rts

say_hello:
    lda #<hello_msg
    sta str_vec
    lda #>hello_msg
    sta str_vec + 1
    jsr print_str
    rts

via_init:
    lda #%11111111  ; Set ALL pins on port B to output
    sta DDRB
    lda #%11000000  ; Set top pin on port A to output
    sta DDRA

    lda #PORTA_OFF
    sta PORTA
    rts

snd_init:
    ; silence all channels
    lda #$9F
    jsr snd_instr
    lda #$BF
    jsr snd_instr
    lda #$DF
    jsr snd_instr
    lda #$FF
    jsr snd_instr
    rts


snd_instr:
    sta PORTB
    lda #SND_E
    sta PORTA
    jsr wait_tick
    lda #PORTA_OFF
    sta PORTA
    rts

lcd_init:
    ; lda #%11111111  ; Set ALL pins on port B to output
    ; sta DDRB
    ; lda #%10000000  ; Set top pin on port A to output
    ; sta DDRA

    ; lda #PORTA_OFF
    ; sta PORTA

   ;lda #%00111000  ; Set 8bit mode; 2-line display; 5x8 font
    lda #%00101000  ; Set 4bit mode; 2-line display; 5x8 font
    jsr lcd_inst

    lda #%00001110  ; Disply on, Cursor on; blink off
    jsr lcd_inst

    lda #%00000110  ; Increment and shift cursor; don't shift display
    jsr lcd_inst

    jsr lcd_clear

    rts

lcd_wait:
    pha
    lda #%00001111  ; port B (high) is input
    sta DDRB
lcd_busy:
    lda #RW
    sta PORTB
    lda #LCD_E
    sta PORTA
    lda PORTB
    pha
    lda #PORTA_OFF
    sta PORTA

    lda #RW
    sta PORTB
    lda #LCD_E
    sta PORTA
    lda PORTB
    lda #PORTA_OFF
    sta PORTA

    pla
    and #%10000000
    bne lcd_busy

    lda #%11111111  ; port B (high) is output
    sta DDRB
    pla
    rts

lcd_inst:
    jsr lcd_wait
    pha
    and #$F0
    sta PORTB
    ; lda #PORTA_OFF          ; Clear Rs/RW/E bits
    ; sta PORTA
    lda #LCD_E                  ; Set E bit to send instruction
    sta PORTA
    lda #PORTA_OFF          ; Clear Rs/RW/E bits
    sta PORTA
    pla
    asl
    asl
    asl
    asl
    sta PORTB
    ; lda #0                ; Clear Rs/RW/E bits
    ; sta PORTA
    lda #LCD_E                  ; Set E bit to send instruction
    sta PORTA
    lda #PORTA_OFF          ; Clear Rs/RW/E bits
    sta PORTA
    rts

print_ch:
    pha
    jsr lcd_wait
    pha
    and #$F0
    ora #RS           ; Set RS; Clear RW/E bits
    sta PORTB
    ; lda #RS         ; Set RS; Clear RW/E bits
    ; sta PORTA
    lda #LCD_E   ; Set E bit to send instruction
    sta PORTA
    lda #PORTA_OFF         ; Clear E bit
    sta PORTA
    pla

    asl
    asl
    asl
    asl
    ora #RS
    sta PORTB
    ; lda #RS         ; Set RS; Clear RW/E bits
    ; sta PORTA
    lda #LCD_E   ; Set E bit to send instruction
    sta PORTA
    lda #PORTA_OFF         ; Clear E bit
    sta PORTA
    pla
    rts

lcd_clear:
    lda #%00000001  ; Cleardisplay
    jsr lcd_inst
    rts

timer_init:
    lda #0
    sta ticks
    sta ticks + 1
    sta ticks + 2
    sta ticks + 3
    lda #%01000000  ; T1 continuous interrupt ; PB7 disabled
    sta ACR
    lda #$0E        ; Set the counter to (n + 2) = 10,000 µs
    sta T1CL        ; 9,998 = $270E
    lda #$27
    sta T1CH
    lda #%11000000  ; enable Timer 1 interrupts
    sta IER
    cli
    rts

irq:
    bit T1CL        ; reading clears the interrupt
    inc ticks
    bne :+
    inc ticks + 1
    bne :+
    inc ticks + 2
    bne :+
    inc ticks + 3
:   ply             ; restore registers
    plx
    pla
    rti

break:
    ldx #$05        ; pull registers off the stack
:   pla             ; order y_reg, x_reg, a_reg, s_reg, pc_reg
    sta pc_reg_hi,x
    dex
    bpl :-
    cld             ; disable BCD mode (just in case)
    tsx             ; store sp_reg in memory
    stx sp_reg
    cli             ; re-enable interrupts

    lda #$07        ; BELL
    jsr put_chr

    jsr print_registers

    jmp print_prompt

irq_brk:
    pha
    phx
    phy
    tsx
    lda $104,x      ; load status register
    and #$10        ; is the break flag set?
    beq :+
    jmp break
:   jmp irq

    .segment "RODATA"
    .feature string_escapes

welcome:
    .asciiz "I'm a computer!\r\n"

hex_lookup:
    .byte "0123456789ABCDEF"

print_reg_msg:
    .asciiz "   pc  sr ac xr yr sp\r\n"

hello_msg:
    .asciiz "Hello There!\r\n"

; debug_text:
;     !raw "\r\ndebug\r\n\0"

    .segment "VECTORS"
    .res 2
    .word reset
    .word irq_brk
