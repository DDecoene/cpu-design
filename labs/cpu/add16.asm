; 16-bit optelling: (R2:R1) + (R4:R3) = (R6:R5). Hier 0x01FF + 0x0001 = 0x0200.
        LDI  R1, 0xFF       ; eerste getal, laag
        LDI  R2, 0x01       ; eerste getal, hoog
        LDI  R3, 0x01       ; tweede getal, laag
        LDI  R4, 0x00       ; tweede getal, hoog
        ADD  R6, R2, R4     ; hoge bytes eerst (de carry uit het lage byte komt erna)
        ADD  R5, R1, R3     ; lage bytes: zet de carry-vlag
        BCC  klaar
        ADDI R6, 1          ; carry doorgeven
klaar:  HALT
