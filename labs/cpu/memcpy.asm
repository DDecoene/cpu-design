; FILE: cpu/memcpy.asm
; Kopieert 8 bytes van adres 16 naar adres 48.
        .data 16, 11, 22, 33, 44, 55, 66, 77, 88
        LDI  R1, 16         ; bron
        LDI  R2, 48         ; doel
        LDI  R3, 8          ; aantal
lus:    LD   R4, [R1]
        ST   R4, [R2]
        ADDI R1, 1
        ADDI R2, 1
        ADDI R3, -1
        BNE  lus
        HALT
