; FILE: cpu/sort.asm
; Bubble sort van 8 bytes op adres 16..23 (zonder teken, oplopend).
        .data 16, 90, 3, 200, 17, 55, 1, 128, 77
        LDI  R1, 7          ; aantal doorlopen
outer:  LDI  R2, 0          ; index i
        LDI  R3, 16         ; basisadres
inner:  ADD  R4, R3, R2     ; adres = basis + i
        LD   R5, [R4]       ; a
        LD   R6, [R4+1]     ; b
        CMP  R5, R6
        BCC  noswap         ; a < b: in orde
        ST   R6, [R4]       ; verwissel
        ST   R5, [R4+1]
noswap: ADDI R2, 1
        CMP  R2, R1
        BCC  inner          ; zolang i < R1
        ADDI R1, -1
        BNE  outer
        HALT
