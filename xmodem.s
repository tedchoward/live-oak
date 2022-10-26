; XMODEM routines, inspired by: http://6502.org/source/io/xmodem/xmodem-receive.txt

    .import poll_chr, put_chr

    .export xmodem

    .segment "CODE"

; --- Zero Page ---
    checksum  = $38   ; checksum
    ptr       = $3a   ; data pointer (2 bytes)
    blkno     = $3c   ; block number
    retry     = $3d   ; retry counter
    retry2    = $3e   ; 2nd counter
    bflag     = $3f   ; block flag

    rbuff = $0300

; constants
    SOH = $01
    EOT = $04
    ACK = $06
    NAK = $15
    CAN = $18
    CR  = $0d
    LF  = $0a
    ESC = $1b

xmodem:
    jsr print_begin_message
    lda #$01
    sta blkno       ; set block # to 1
    sta bflag       ; set flag to get address from block 1
start_xmdm:
    lda #NAK        ; send a NAK to indicate we are ready to receive
    jsr put_chr
    lda #$FF
    sta retry2      ; set loop counter for ~3 second delay
    stz checksum
    jsr get_byte   ; wait for input
    bcs got_byte   ; byte received. process it
    bcc start_xmdm ; resend NAK

start_blk:
    lda #$ff
    sta retry2      ; set loop counter for ~3 second delay
    stz checksum    ; init checksum value
    jsr get_byte   ; get furst byte of block
    bcc start_blk  ; timed out, keep waiting...

got_byte:
    cmp #ESC        ; quitting?
    bne :+          ; no
    lda #$FE        ; Error code in "A" of desired
    brk             ; YES = do BRK or change to RTS if desired
:   cmp #SOH        ; start of block?
    beq begin_blk  ; yes
    cmp #EOT
    bne bad_check  ; not SOH or EOT, so flush buffer and send NAK
    jmp done       ; EOT - all done!

begin_blk:
    ldx #$00
get_blk:
    lda #$FF        ; 3 second window to receive characters
    sta retry2
    jsr get_byte   ; get next character
    bcc bad_check  ; chr rcv error, flush and send NAK
    sta rbuff,x     ; good char, save it in the recv buffer
    inx             ; increment buffer pointer
    cpx #$83        ; <01> <FE> <128 bytes> <checksum>
    bne get_blk    ; get 131 characters
    ldx #$00
    lda rbuff,x     ; get block # from buffer
    cmp blkno       ; compare to expected block #
    beq good_blk   ; matched!
    jsr print_err  ; Unexpected block number - abort
    jsr flush      ; mismatched - flush buffer and then do brk
    lda #$FD        ; put error code in "A" if desired
    brk             ; unexpected block # - fatal error - BRK or RTS

good_blk:
    eor #$ff        ; 1's compliment of block #
    inx
    cmp rbuff,x     ; compare with expected 1's comp of block #
    beq :+          ; matched
    jsr print_err  ; Unexpected block number - abort
    jsr flush      ; mismatched - flush buffer and then do brk
    lda #$FC        ; put error code in "A" if desired
    brk             ; bad 1's compliment block # - fatal error - BRK or RTS
:   ldy #$02
    stz checksum
calc_check:
    lda rbuff,y     ; calculate the checksum for the 128 bytes of data
    clc
    adc checksum
    sta checksum
    iny
    cpy #$82        ; 128 bytes
    bne calc_check
    lda rbuff,y     ; get expected checksum from buffer
    cmp checksum    ; compare to calculated checksum
    beq good_check

bad_check:
    jsr flush      ; flush the input port
    lda #NAK
    jsr put_chr     ; send NAK to resen block
    bra start_blk  ; start over, get the block again

good_check:
.scope
    ldx #$02
store_byte:
    lda rbuff,x     ; get data byte from buffer
    sta (ptr)       ; save to target
    inc ptr
    bne skip_hi
    inc ptr + 1
skip_hi:
    inx             ; point to next data byte
    cpx #$82        ; is it the last byte?
    bne store_byte  ; no, get the next one
    inc blkno       ; done. Inc the block #
    lda #ACK
    jsr put_chr     ; send ACK
    jmp start_blk  ; get next block
.endscope

done:
    lda #ACK
    jsr put_chr     ; last block, send ACK and exit.
    jsr flush      ; get leftover characters if any
    jsr print_good
    rts


get_byte:
    stz retry       ; wait for chr input and cycle timing loop
:   jsr poll_chr    ; get chr from serial port, don't wait
    bcs :+          ; got one, so exit
    dec retry       ; no character received, so decrement counter
    bne :-
    dec retry2      ; dec hi byte of counter
    bne :-           ; look for character again
    clc             ; of loop times out, CLC, else SEC and return
:   rts             ; with character in A

flush:
    lda #$70        ; flush receive buffer
    sta retry2      ; flush until empty for ~1 sec
:   jsr get_byte    ; read the port
    bcs :-          ; if chr received, wait for another
    rts             ; else done

print_begin_message:
    ldx #$00
:   lda begin_message,x
    beq :+
    jsr put_chr
    inx
    bne :-
:   rts

print_err:
    ldx #$00
:   lda error_message,x
    beq :+
    jsr put_chr
    inx
    bne :-
:   rts

print_good:
    ldx #$00
:   lda good_message,x
    beq :+
    jsr put_chr
    inx
    bne :-
:   rts

    .segment "RODATA"
    .feature string_escapes

begin_message:
    .asciiz "Begin XMODEM transfer. Press <Esc> to abort...\r\n"

error_message:
    .asciiz "Upload Error!\r\n"

good_message:
    .asciiz "Upload Successful!\r\n"
