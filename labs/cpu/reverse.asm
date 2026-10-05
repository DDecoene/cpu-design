; FILE: cpu/reverse.asm
; Keert de bits van R1 om (0xB4 -> 0x2D). Resultaat in R2.
        LDI  R1, 0xB4
        LDI  R2, 0
        LDI  R3, 8
lus:    SHL  R2, R2         ; ruimte maken
        SHR  R1, R1         ; carry = laagste bit van R1
        BCC  nul
        ADDI R2, 1
nul:    ADDI R3, -1
        BNE  lus
        HALT
