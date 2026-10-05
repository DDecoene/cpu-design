; FILE: cpu_irq/hello.asm
; Zegt "W8 OK" via de UART en laat daarna een LED knipperen met de timer.
; Op de FPGA is een timertik 1 ms, dus 250 betekent: de LED wisselt elke 250 ms.
        .data 16, 0x57, 0x38, 0x20, 0x4F, 0x4B, 0x0D, 0x0A, 0   ; "W8 OK" + nieuwe regel + einde
        B    main
        .org 2
isr:    LDI  R6, 0xE0
        ST   R0, [R6+0]         ; R0 bewaren
        LDI  R6, 0xF5
        LD   R0, [R6]           ; LED-toestand
        LDI  R6, 1
        XOR  R0, R0, R6         ; bit 0 omkeren
        LDI  R6, 0xF5
        ST   R0, [R6]
        LDI  R6, 0xF3
        ST   R0, [R6]           ; timer-aanvraag wissen
        LDI  R6, 0xE0
        LD   R0, [R6+0]
        RETI

main:   LDI  R4, 0xF0           ; UART data
        LDI  R5, 0xF1           ; UART status
        LDI  R2, 16             ; begin van de tekst
volgende:
        LD   R1, [R2]
        CMPI R1, 0
        BEQ  klaar
        CALL send
        ADDI R2, 1
        B    volgende
klaar:  LDI  R4, 0xF2
        LDI  R5, 250
        ST   R5, [R4]           ; timer: 250 tikken
        LDI  R4, 0xF7
        LDI  R5, 1
        ST   R5, [R4]           ; timer-interrupt aan
        EI
slaap:  B    slaap

send:   LD   R0, [R5]
        LDI  R3, 1
        AND  R0, R0, R3
        BNE  send               ; wacht tot de zender vrij is
        ST   R1, [R4]
        RET
