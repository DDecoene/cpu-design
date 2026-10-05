; FILE: cpu/strlen.asm
; Lengte van een tekst met 0 als einde. De tekst "HELLO" staat op adres 32.
        .data 32, 72, 69, 76, 76, 79, 0
        LDI  R1, 32         ; wijzer
        LDI  R2, 0          ; lengte
lus:    LD   R3, [R1]
        CMPI R3, 0
        BEQ  klaar
        ADDI R1, 1
        ADDI R2, 1
        B    lus
klaar:  HALT
