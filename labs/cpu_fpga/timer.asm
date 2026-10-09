; Een timer-interrupt tijdens een rekenlus. R6 is gereserveerd voor de interruptroutine.
; De hoofdlus telt 1+2+...+200 (modulo 256 = 132). De routine telt op adres 0x20 hoe vaak hij draaide.
        B    main
        .org 2
isr:    LDI  R6, 0xE0
        ST   R0, [R6+0]         ; R0 bewaren (R6 is van ons)
        LDI  R6, 0x20
        LD   R0, [R6]           ; teller in het geheugen
        ADDI R0, 1
        ST   R0, [R6]
        LDI  R6, 0xF3
        ST   R0, [R6]           ; schrijven naar 0xF3 wist de timer-aanvraag
        LDI  R6, 0xE0
        LD   R0, [R6+0]         ; R0 terug
        CMP  R0, R0             ; bewust de vlaggen verpesten (Z = 1), om te bewijzen dat ze hersteld worden
        RETI                    ; PC en vlaggen worden automatisch hersteld

main:   LDI  R1, 0              ; som
        LDI  R3, 200            ; teller
        LDI  R4, 0xF2
        LDI  R5, 40
        ST   R5, [R4]           ; timer: om de 40 klokcycli een aanvraag
        LDI  R4, 0xF7
        LDI  R5, 1
        ST   R5, [R4]           ; timer-interrupt toestaan
        EI
lus:    ADD  R1, R1, R3
        ADDI R3, -1
        BNE  lus                ; de vlaggen van ADDI blijven heel, ook als er een interrupt tussen komt
        DI
        HALT
