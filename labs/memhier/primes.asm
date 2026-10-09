; Zeef van Eratosthenes voor 2..99. Vlaggen op adres 100+n. R3 = aantal priemgetallen (25).
        LDI  R6, 100        ; basisadres van de vlaggen
        LDI  R3, 0          ; aantal priemgetallen
        LDI  R1, 2          ; p = 2
ploop:  ADD  R4, R6, R1
        LD   R5, [R4]       ; vlag van p
        CMPI R5, 0
        BNE  next           ; al doorgestreept: geen priemgetal
        ADDI R3, 1          ; p is priem
        ADD  R2, R1, R1     ; m = 2p
mloop:  CMPI R2, 100
        BCS  next           ; m >= 100: klaar met doorstrepen
        ADD  R4, R6, R2
        LDI  R5, 1
        ST   R5, [R4]       ; streep m door
        ADD  R2, R2, R1     ; m += p
        B    mloop
next:   ADDI R1, 1
        CMPI R1, 100
        BCC  ploop          ; p < 100
        HALT
