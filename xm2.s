; vim: set filetype=asm_ca65:

	.import poll_chr, put_chr
	.segment "CODE"

; --- Zero Page ---
	XMODEM_POLL_TIMEOUT	= $02
	PACKET_NUM		= $03
	CHECKSUM		= $04
	DATA_DESTINATION	= $05	; 2 bytes

	READ_BUFFER	= $0300

; --- Constants ---
	ACIA_DATA	= $C010
	ACIA_STATUS	= $C011
	ACIA_COMMAND	= $C012
	ACIA_CONTROL	= $C013

	TIMEOUT_10	= $13
	TIMEOUT_1	= $02

	SOH		= $01
	EOT		= $04
	ACK		= $06
	NAK		= $15

xmodem_receive:
	; determine where in memory to store received bytes

	lda	#$01
	sta	PACKET_NUM

retry_packet:
	lda	TIMEOUT_10
	sta	XMODEM_POLL_TIMEOUT

	; Start the process by sending a NAK
send_nak:
	lda	#NAK
	jsr	put_chr
receive_packet:
	jsr	xmodem_poll
	bcc	send_nak	; TODO: only retry 10 times

	cmp	#EOT
	beq	end_of_transmission

	cmp	#SOH		; start of a vaild packet
	bne	send_nak	; TODO: only retry 10 times

	; Once we are processing a valid packet, switch to 1 second timeout
	lda	TIMEOUT_1
	sta	XMODEM_POLL_TIMEOUT

	; Now we'll read the entire packet into a buffer
	; once the whole packet has been received we will validate
	; - the 1st byte contains the correct packet num
	; - the 2nd byte contains the EOR of the packet num
	; - the last byte is a valid checksum of all data bytes
	;
	; If everything validates, the data bytes should be copied to the
	; destination, PACKET_NUM should be incremented, and the next
	; packet fetched.
	;
	; Packet Structure (132 bytes total)
	; [SOH] [packet_num] [EOR packetnum] [128 data bytes] [checksum]

	ldx	#$00
next_byte:
	jsr	xmodem_poll
	bcc	error
	sta	READ_BUFFER, x
	inx
	cpx	#132
	bne	next_byte

	; At this point we have stored a complete packet in READ_BUFFER

	; First, validate the packet number
	lda	READ_BUFFER
	cmp	PACKET_NUM	; is this the block we are expecting?
	bne	error		; TODO better error handling

	; next, validate the complement
	eor	$FF
	cmp	READ_BUFFER+1
	bne	error

	; then calculate the checksum
	ldx	#$02
	stz	CHECKSUM
csum_byte:
	lda	READ_BUFFER, X
	clc
	adc	CHECKSUM
	sta	CHECKSUM
	inx
	cpx	#131		; the index of the sent checksum
	bne	csum_byte

	; now validate the checksum
	lda	READ_BUFFER, X
	cmp	CHECKSUM
	bne	error

	; At this point, all the validations have passed. We need to copy the
	; data to it's actual destination.

	ldx	#$02
	ldy	#$00
copy_byte:
	lda	READ_BUFFER, X
	sta	(DATA_DESTINATION),Y
	inx
	iny
	cpy	#$80
	bne	copy_byte

	clc
	lda	DATA_DESTINATION
	adc	#$80
	lda	DATA_DESTINATION+1
	adc	#$00

	; With the data copied, and the destination incremented, it's time to
	; request the next packet

	inc	PACKET_NUM

	lda	TIMEOUT_10
	sta	XMODEM_POLL_TIMEOUT

	lda	#ACK
	jsr	put_chr
	bra	receive_packet

end_of_transmission:
	lda	#ACK
	jsr	put_chr
	rts

error:
	rts





; This is a variation of poll_chr from uart excep that it has some auto-retry
; built in. outer_loop + inner_loop takes ~0.5 secs. The number of iterations
; for the main loop is set in A. (19 iterations is ~10 secs)
.proc xmodem_poll
	phx
	sta	XMODEM_POLL_TIMEOUT
main_loop:
	ldy	#$FF
outer_loop:
	ldx	#$FF
inner_loop:
	lda	ACIA_STATUS
	and	#$08		; reeiver data register full?
	bne	rx_register_full
	dex
	bne	inner_loop
	dey
	bne	outer_loop
	dec	XMODEM_POLL_TIMEOUT
	bne	main_loop
	clc			; clear carry bit to indicate no data received
	plx
	rts
rx_register_full:
	lda	ACIA_DATA
	sec			; set carry bit to indicate data received
	plx
	rts
.endproc
