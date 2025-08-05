; vim: set filetype=asm_ca65:

; Interrupt Handling Logic
;
; This sets up a 60Hz timer that increments a 32-bit integer (`ticks`)


	.import keyboard_interrupt_handler
	.export irq_init, irq_brk, ticks

	VIA_T1CL	= $C004
	VIA_T1CH	= $C005
	VIA_ACR		= $C00B
	VIA_IFR		= $C00D
	VIA_IER		= $C00E

.zeropage

ticks:	.dword $00000000

.code

; Clears the doubleword `ticks` and initializes the VIA's Timer 1 to fire an
; interrupt every 26,250 cycles (60Hz)
irq_init:
	stz ticks
	stz ticks+1
	stz ticks+2
	stz ticks+3

	lda #$40
	sta VIA_ACR

	; 60 ticks/second at 1.573MHz ~= 26,250 (0x668A)
	; set counter to (n + 2) = 26,250 = 26,248 (0x6688)
	lda #$88
	sta VIA_T1CL
	lda #$66
	sta VIA_T1CH

	; Enable Timer 1 Interrupts
	lda #$C0
	sta VIA_IER

	rts

; This is the IRQ Vector. It branches to the break handler if the B flag is set.
; Otherwise, it falls through to the irq handler
irq_brk:
	pha
	phx
	tsx
	lda $103,x		; read S register from stack
	and #$10		; and check for B flag
	bne break_handler

; The IRQ handler validates that the interrupt came from the VIA, and from
; Timer 1. In that case, it increments the 32-bit value `ticks` and returns.
irq_handler:
	bit VIA_IFR
	bpl :+
	bvc :+

	jsr keyboard_interrupt_handler

	; timer 1 handler
	bit VIA_T1CL	; clear the interrupt
	inc ticks
	bne :+
	inc ticks+1
	bne :+
	inc ticks+2
	bne :+
	inc ticks+3
:
; the break handler does nothing currently, so irq can safely fall through
break_handler:
	plx
	pla
	rti
