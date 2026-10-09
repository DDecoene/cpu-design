; Telt de bits die 1 zijn in R1 (0xB7 heeft er 6). Resultaat in R2.
        LDI  R1, 0xB7
        LDI  R2, 0
        LDI  R3, 8          ; 8 bits
lus:    SHR  R1, R1         ; carry = het uitgeschoven bit
        BCC  nul
        ADDI R2, 1
nul:    ADDI R3, -1
        BNE  lus
        HALT
