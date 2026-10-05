; FILE: cpu_irq/uart.asm
; Verzend "HI" via de UART en lees het terug (de testbench sluit de zender aan op de ontvanger).
; Gebruikt polling: wachten tot de zender vrij is of er een byte is ontvangen.
        LDI  R4, 0xF0           ; UART data
        LDI  R5, 0xF1           ; UART status
        LDI  R1, 0x48           ; 'H'
        CALL send
        LDI  R1, 0x49           ; 'I'
        CALL send
        LDI  R2, 0x30           ; hier komen de ontvangen bytes
        CALL recv
        ST   R1, [R2]
        ADDI R2, 1
        CALL recv
        ST   R1, [R2]
        HALT

send:   LD   R0, [R5]           ; status
        LDI  R3, 1
        AND  R0, R0, R3         ; bit 0 = zender bezig
        BNE  send               ; wacht tot de zender vrij is
        ST   R1, [R4]           ; verzenden
        RET

recv:   LD   R0, [R5]
        LDI  R3, 2
        AND  R0, R0, R3         ; bit 1 = byte ontvangen
        BEQ  recv
        LD   R1, [R4]           ; lezen wist de 'ontvangen'-vlag
        RET
