; FILE: beeld/boot.asm
; Het bootprogramma van de beeldcomputer: start de SD-kaart op, lees 19 blokken van 512 bytes en zet ze in het framebuffer.
; De LED's (GPIO) laten zien waar het programma is: 1 = klokpulsen, 2 = CMD0 gelukt, 3 = CMD8 gelukt (de kaart start op),
; 4 = kaart klaar, 5 = bezig met lezen, 0x10 = klaar. Bit 7 erbij betekent: fout in die stap.
;
; Registers: R3 = 0xF0 (basis van alle apparaten), R7 = terugkeeradres (CALL), R0 = byte voor/na een SPI-overdracht.
;
; Datageheugen: de zes bytes van elk SD-commando (commandobyte, 4 bytes argument, CRC). Alleen CMD0 en CMD8 hebben een echte CRC nodig.
        .data 0x10, 0x40, 0x00, 0x00, 0x00, 0x00, 0x95     ; CMD0  (GO_IDLE_STATE)
        .data 0x16, 0x48, 0x00, 0x00, 0x01, 0xAA, 0x87     ; CMD8  (SEND_IF_COND), argument 0x1AA
        .data 0x1C, 0x77, 0x00, 0x00, 0x00, 0x00, 0x01     ; CMD55 (APP_CMD)
        .data 0x22, 0x69, 0x40, 0x00, 0x00, 0x00, 0x01     ; ACMD41 (SD_SEND_OP_COND), HCS-bit gezet
        .data 0x28, 0x51, 0x00, 0x00, 0x00, 0x00, 0x01     ; CMD17 (READ_SINGLE_BLOCK); bloknummer in de bytes op 0x2B en 0x2C

start:  LDI  R3, 0xF0
        LDI  R0, 1
        ST   R0, [R3+5]         ; LED's: stap 1
        ST   R0, [R3+13]        ; SPI_CTRL: CS hoog (niet geselecteerd), langzame klok
        LDI  R4, 10             ; 10 bytes = 80 klokpulsen met CS hoog: de kaart zet zich in SPI-modus
init:   LDI  R0, 0xFF
        CALL xfer
        ADDI R4, -1
        BNE  init
        LDI  R0, 0
        ST   R0, [R3+13]        ; CS laag: kaart geselecteerd

        LDI  R2, 0x10
        CALL cmd                ; CMD0
        CMPI R0, 0x01           ; verwacht R1 = 0x01 (idle)
        BNE  fout
        LDI  R0, 2
        ST   R0, [R3+5]

        LDI  R2, 0x16
        CALL cmd                ; CMD8
        CMPI R0, 0x01
        BNE  fout
        LDI  R4, 4              ; de rest van het antwoord (4 bytes) lezen en weggooien
r7:     LDI  R0, 0xFF
        CALL xfer
        ADDI R4, -1
        BNE  r7
        LDI  R0, 3
        ST   R0, [R3+5]

opstart: LDI R2, 0x1C
        CALL cmd                ; CMD55: het volgende commando is een 'applicatiecommando'
        LDI  R2, 0x22
        CALL cmd                ; ACMD41
        CMPI R0, 0x00           ; 0x01 = nog bezig met opstarten, probeer opnieuw; 0x00 = klaar
        BNE  opstart
        LDI  R0, 4
        ST   R0, [R3+5]
        LDI  R0, 2
        ST   R0, [R3+13]        ; CS laag en nu de snelle klok

        LDI  R0, 5
        ST   R0, [R3+5]
        LDI  R4, 19             ; 19 blokken van 512 bytes = 9728 bytes, genoeg voor de 9600 bytes van het beeld
blok:   LDI  R2, 0x28
        CALL cmd                ; CMD17
        CMPI R0, 0x00
        BNE  fout
token:  LDI  R0, 0xFF
        CALL xfer
        CMPI R0, 0xFE           ; wacht op het datatoken
        BNE  token
        LDI  R5, 2              ; 512 bytes = 2 x 256
ronde:  LDI  R1, 0              ; 0 telt 256 keer af tot 0 (8 bit)
data:   LDI  R0, 0xFF
        CALL xfer
        ST   R0, [R3+10]        ; FB_DATA: byte (twee pixels) naar het framebuffer
        ADDI R1, -1
        BNE  data
        ADDI R5, -1
        BNE  ronde
        LDI  R0, 0xFF
        CALL xfer               ; twee CRC-bytes lezen en weggooien
        LDI  R0, 0xFF
        CALL xfer
        LDI  R2, 0x2C           ; het bloknummer in het CMD17-commando met 1 ophogen
        LD   R0, [R2]
        ADDI R0, 1
        ST   R0, [R2]
        ADDI R4, -1
        BNE  blok

        LDI  R0, 3
        ST   R0, [R3+13]        ; CS hoog
        LDI  R0, 0xFF
        CALL xfer               ; nog 8 klokpulsen zodat de kaart loslaat
        LDI  R0, 0x10
        ST   R0, [R3+5]         ; klaar
        HALT

fout:   LD   R0, [R3+5]         ; het stapnummer behouden en bit 7 zetten
        LDI  R1, 0x80
        OR   R0, R0, R1
        ST   R0, [R3+5]
        HALT

; xfer: stuur R0 over SPI en wacht tot het klaar is. Terug in R0: het ontvangen byte.
xfer:   ST   R0, [R3+12]        ; SPI_DATA
xwacht: LD   R6, [R3+14]        ; SPI_STATUS
        CMPI R6, 0
        BNE  xwacht
        LD   R0, [R3+12]
        RET

; cmd: stuur het commando van 6 bytes waar R2 naar wijst en wacht op R1 (het eerste byte met bit 7 = 0). Terug in R0: R1.
; Bij een time-out (16 bytes zonder antwoord) is R0 = 0xFF. R5 bewaart het terugkeeradres, want xfer overschrijft R7.
cmd:    MOV  R5, R7
        LDI  R1, 6
cbyte:  LD   R0, [R2]
        CALL xfer
        ADDI R2, 1
        ADDI R1, -1
        BNE  cbyte
        LDI  R1, 16
cantw:  LDI  R0, 0xFF
        CALL xfer
        CMPI R0, 0x80
        BLO  cklaar             ; kleiner dan 0x80: dit is het antwoord
        ADDI R1, -1
        BNE  cantw
cklaar: JR   R5
