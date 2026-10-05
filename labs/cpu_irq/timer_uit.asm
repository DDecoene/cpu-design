; FILE: cpu_irq/timer_uit.asm
; Dezelfde rekenlus, zonder timer: de referentie. Het resultaat moet gelijk zijn aan dat van timer.asm.
        B    main
        .org 2
isr:    RETI
main:   LDI  R1, 0
        LDI  R3, 200
lus:    ADD  R1, R1, R3
        ADDI R3, -1
        BNE  lus
        HALT
