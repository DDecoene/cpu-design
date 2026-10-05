; FILE: cpu/mul.asm
; 16-bit product van 200 x 150 met shift-and-add. Resultaat in R5:R4 (0x7530 = 30000).
        LDI  R1, 200        ; vermenigvuldigtal, laag
        LDI  R2, 0          ; vermenigvuldigtal, hoog
        LDI  R3, 150        ; vermenigvuldiger
        LDI  R4, 0          ; product, laag
        LDI  R5, 0          ; product, hoog
        LDI  R6, 8          ; aantal bits
loop:   LDI  R0, 1
        AND  R0, R3, R0     ; is bit 0 van de vermenigvuldiger 1?
        BEQ  skip
        ADD  R4, R4, R1     ; product(laag) += vermenigvuldigtal(laag)
        BCC  nocar
        ADDI R5, 1          ; carry naar het hoge byte
nocar:  ADD  R5, R5, R2     ; product(hoog) += vermenigvuldigtal(hoog)
skip:   SHL  R2, R2         ; vermenigvuldigtal 16 bit naar links
        SHL  R1, R1         ; carry = bit dat uit R1 viel
        BCC  nc2
        ADDI R2, 1
nc2:    SHR  R3, R3         ; volgende bit van de vermenigvuldiger
        ADDI R6, -1
        BNE  loop
        HALT
