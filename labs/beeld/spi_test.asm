; Test van de SPI-poort met een lus: de testbench verbindt MISO met MOSI, dus elk verzonden byte moet terugkomen.
; Het programma verstuurt 8 bytes, telt hoeveel er goed terugkomen en zet dat aantal op de GPIO-uitgang.
        LDI  R3, 0xF0           ; basisadres van de apparaten
        LDI  R0, 2
        ST   R0, [R3+13]        ; SPI_CTRL: CS = 0 (geselecteerd), snelle klok
        LDI  R2, 0              ; aantal goed ontvangen bytes
        LDI  R4, 0x5A           ; eerste testbyte
        LDI  R6, 8              ; aantal bytes
lus:    ST   R4, [R3+12]        ; SPI_DATA: begin de overdracht
wacht:  LD   R0, [R3+14]        ; SPI_STATUS
        CMPI R0, 0
        BNE  wacht              ; wacht tot de poort klaar is
        LD   R0, [R3+12]        ; SPI_DATA: het ontvangen byte
        CMP  R0, R4
        BNE  mis
        ADDI R2, 1
mis:    ADDI R4, 0x13           ; volgend testbyte
        ADDI R6, -1
        BNE  lus
        LDI  R0, 3
        ST   R0, [R3+13]        ; CS weer hoog
        ST   R2, [R3+5]         ; GPIO: het aantal goede bytes
        HALT
