; Ontvang bytes via een interrupt. De routine zet elke ontvangen byte in een buffer vanaf 0x30
; en telt op adres 0x21. De hoofdlus wacht tot er 3 bytes binnen zijn.
        B    main
        .org 2
isr:    LDI  R6, 0xE0
        ST   R0, [R6+0]         ; R0 en R1 bewaren
        ST   R1, [R6+1]
        LDI  R6, 0xF0
        LD   R0, [R6]           ; de ontvangen byte (wist ook de aanvraag)
        LDI  R6, 0x21
        LD   R1, [R6]           ; aantal tot nu toe
        ST   R0, [R1+0x30]      ; buffer[aantal] = byte
        ADDI R1, 1
        ST   R1, [R6]           ; aantal verhogen
        LDI  R6, 0xE0
        LD   R0, [R6+0]
        LD   R1, [R6+1]
        RETI

main:   LDI  R4, 0xF7
        LDI  R5, 2
        ST   R5, [R4]           ; UART-ontvangst-interrupt toestaan
        EI
        LDI  R2, 0x21
wacht:  LD   R3, [R2]           ; hoofdlus: kijk hoeveel er binnen zijn
        CMPI R3, 3
        BCC  wacht              ; minder dan 3: doorgaan met wachten
        DI
        HALT
