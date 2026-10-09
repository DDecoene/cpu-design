; Som van 1 tot 10. Resultaat in R1 (55).
        LDI  R1, 0          ; som
        LDI  R2, 10         ; teller
loop:   ADD  R1, R1, R2
        ADDI R2, -1         ; zet de Z-vlag als R2 nul wordt
        BNE  loop
        HALT
