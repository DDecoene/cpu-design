; FILE: cpu_irq/blink.asm
; Knipperlicht: de timer-interrupt wisselt bit 0 van de GPIO-uitgang (een LED). De hoofdlus doet niets.
        B    main
        .org 2
isr:    LDI  R6, 0xE0
        ST   R0, [R6+0]         ; R0 bewaren
        LDI  R6, 0xF5
        LD   R0, [R6]           ; huidige LED-toestand
        LDI  R6, 1
        XOR  R0, R0, R6         ; bit 0 omkeren
        LDI  R6, 0xF5
        ST   R0, [R6]           ; terug naar de LED
        LDI  R6, 0xF3
        ST   R0, [R6]           ; timer-aanvraag wissen
        LDI  R6, 0xE0
        LD   R0, [R6+0]         ; R0 terug
        RETI

main:   LDI  R4, 0xF2
        LDI  R5, 100
        ST   R5, [R4]           ; elke 100 cycli een tik
        LDI  R4, 0xF7
        LDI  R5, 1
        ST   R5, [R4]           ; timer-interrupt aan
        EI
slaap:  B    slaap              ; de hoofdlus wacht eeuwig; alles gebeurt in de interruptroutine
