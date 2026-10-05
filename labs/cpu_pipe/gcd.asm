; FILE: cpu/gcd.asm
; Grootste gemene deler van 252 en 105 (Euclides met aftrekken). Resultaat in R1 (21).
        LDI  R1, 252
        LDI  R2, 105
loop:   CMP  R1, R2
        BEQ  done
        BCC  less           ; R1 < R2
        SUB  R1, R1, R2
        B    loop
less:   SUB  R2, R2, R1
        B    loop
done:   HALT
