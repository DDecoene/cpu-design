; Vult het hele scherm met 16 verticale balken, een per palletkleur, en meldt dat het klaar is.
; Een byte bevat twee pixels, dus het byte 0x00 is twee zwarte blokken, 0x11 twee blauwe, enzovoort tot 0xFF (wit).
; Elke balk is 5 bytes = 10 blokken breed, 16 balken = 80 bytes = een volle rij.
        LDI  R3, 0xF0           ; basisadres van de apparaten: alles hieronder is [R3 + offset]
        LDI  R0, 0
        ST   R0, [R3+8]         ; FB_LO = 0
        ST   R0, [R3+9]         ; FB_HI = 0: begin linksboven
        LDI  R6, 120            ; 120 rijen
rij:    LDI  R1, 0x00           ; kleur in beide nibbles: 0x00, 0x11, ... 0xFF
        LDI  R4, 16             ; 16 balken per rij
balk:   LDI  R2, 5              ; 5 bytes per balk
byte:   ST   R1, [R3+10]        ; FB_DATA: schrijf twee pixels, het adres loopt zelf op
        ADDI R2, -1
        BNE  byte
        LDI  R0, 0x11
        ADD  R1, R1, R0         ; volgende kleur
        ADDI R4, -1
        BNE  balk
        ADDI R6, -1
        BNE  rij
        LDI  R0, 1
        ST   R0, [R3+5]         ; GPIO bit 0 = klaar
        HALT
