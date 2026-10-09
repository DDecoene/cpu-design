; Subroutines met CALL en RET. R7 bevat het terugkeeradres, dus een geneste aanroep moet het bewaren.
        LDI  R1, 3
        CALL kwadraat       ; R2 = R1 * R1 via herhaald optellen
        MOV  R3, R2         ; bewaar het resultaat
        LDI  R1, 12
        CALL kwadraat
        HALT                ; R3 = 9, R2 = 144
kwadraat:
        LDI  R2, 0
        MOV  R4, R1         ; teller
kloop:  ADD  R2, R2, R1
        ADDI R4, -1
        BNE  kloop
        RET
