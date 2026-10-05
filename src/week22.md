---
title: "Week 22 · Interrupts en I/O (UART, timer)"
---

<p class="subtitle">Fase 5 · Geavanceerde architecturen · ongeveer 13 uur</p>

# Week 22: Interrupts en I/O

## Wat je na deze week kunt

- uitleggen hoe een CPU met de buitenwereld praat: memory-mapped I/O, polling en interrupts
- een UART (seriële poort) ontwerpen: zender en ontvanger, met baudrate-deler en synchronizer
- een timer bouwen en gebruiken
- een CPU uitbreiden met interrupts: aanvraag, vectorsprong, toestand bewaren en `RETI`
- een interruptroutine schrijven en bewijzen dat ze het hoofdprogramma niet verstoort

## 1. Een CPU met een buitenwereld

Een processor die alleen rekent, is nutteloos. Hij moet toetsen kunnen lezen, lampjes laten branden, tekst versturen en weten hoe laat het is. Daarvoor gebruik je apparaten (peripherals) die de CPU als geheugenplaatsen ziet.

### Memory-mapped I/O

Sommige adressen van het datageheugen zijn geen RAM maar de registers van een apparaat. Lezen en schrijven met `LD` en `ST` gaat dan naar het apparaat. Dat heet memory-mapped I/O. Het is elegant: je hebt geen aparte I/O-instructies nodig, en alles wat je met geheugen kunt doen, kun je ook met apparaten doen.

(De andere aanpak is port-mapped I/O, met speciale instructies `IN` en `OUT`, zoals bij x86 en de Z80.)

### De geheugenkaart van W8I

| Adres | Naam | Gedrag |
|:-----:|------|--------|
| `0x00`-`0xEF` | RAM | gewoon geheugen (240 bytes) |
| `0xF0` | UART data | schrijven: verzend een byte. Lezen: de ontvangen byte (wist de vlag "ontvangen") |
| `0xF1` | UART status | bit 0: zender bezig. Bit 1: byte ontvangen |
| `0xF2` | Timer herlaadwaarde | om de N klokcycli een aanvraag; 0 = uit |
| `0xF3` | Timer status | lezen: bit 0 = aanvraag. Schrijven: de aanvraag wissen |
| `0xF5` | GPIO uit | bijvoorbeeld LED's |
| `0xF6` | GPIO in | bijvoorbeeld schakelaars |
| `0xF7` | Interrupt-aan | bit 0: timer, bit 1: UART ontvangen |

## 2. De UART

Een UART (universal asynchronous receiver/transmitter) stuurt bytes over één draad, bit na bit, zonder gedeelde klok. Zender en ontvanger spreken alleen een baudrate af (bits per seconde).

### Het frame

```text
 lijn:  ‾‾‾‾‾‾‾\____/‾‾‾\____/‾‾‾‾\_/‾‾‾\_____/‾‾‾‾‾‾‾‾‾‾
 rust   │start│ d0 │ d1 │ d2 │ ... │ d7 │stop│ rust
        0     LSB                    MSB   1
```

De lijn is in rust hoog (1). Een byte begint met een startbit (0): de daling vertelt de ontvanger dat er iets aankomt. Daarna volgen 8 databits, de laagste eerst. Een stopbit (1) sluit af, en de lijn blijft hoog tot het volgende startbit.

Elke bit duurt `DIV` klokcycli van de CPU (het "clocks per bit"-getal).

### Welk getal voor DIV?

```text
 DIV = klokfrequentie / baudrate
```

Voor 9600 baud op een klok van 4 MHz: 4 000 000 / 9600 = 416,67, dus kies je 417. De fout is 0,08 %. Een UART verdraagt ongeveer 3 tot 5 % fout, omdat de ontvanger bij de laatste bit nog in het midden moet kunnen kijken.

### De zender

De zender is een schuifregister van 10 bits (`1`, 8 databits, `0`) dat om de `DIV` cycli één plek opschuift. Tijdens het verzenden is de zender bezig (`tx_busy`).

### De ontvanger

De ontvanger is lastiger, want hij kent de timing van de zender niet:

1. Hij wacht op een daling van de lijn. De ingang gaat eerst door de synchronizer (twee flipflops, week 6), want het signaal komt van buiten en is niet gesynchroniseerd met onze klok.
2. Hij wacht een halve bitperiode, zodat hij in het midden van het startbit staat. Is de lijn daar nog 0, dan is het een echte start.
3. Daarna samplet hij om de `DIV` cycli, steeds in het midden van een bit, waar de lijn het stabielst is.
4. Na 8 databits controleert hij het stopbit. Klopt dat, dan staat de byte klaar en zet hij de vlag "ontvangen".

## 3. De timer

Een teller telt klokcycli. Bij een instelbare waarde zet hij een aanvraagvlag (`t_pend`) en begint hij opnieuw. De CPU moet de aanvraag wissen (schrijven naar `0xF3`), anders blijft hij staan.

Timers geven de CPU een gevoel voor tijd: een lampje laten knipperen, een time-out of een vaste meetfrequentie.

De timer heeft een prescaler: de parameter `TDIV` bepaalt hoeveel klokcycli één tik duurt. In de simulatie is `TDIV = 1` (een tik per cyclus). Op een echte FPGA van 27 MHz kies je `TDIV = 27000`, zodat één tik 1 ms is en een herlaadwaarde van 250 een periode van 250 ms geeft. Een 8-bit teller zonder prescaler zou bij 27 MHz maar 9 microseconden kunnen tellen, veel te snel om een LED te zien knipperen.

## 4. Polling of interrupt?

Hoe weet de CPU dat er een byte is ontvangen?

Bij polling kijkt de CPU zelf steeds in het statusregister. Dat is eenvoudig, maar het wachten neemt hem volledig in beslag. Bij een interrupt meldt het apparaat zich zelf, en laat de CPU zijn werk even liggen om het af te handelen. Intussen kan de CPU nuttig werk doen.

| | Polling | Interrupt |
|--|---------|-----------|
| Hardware | geen | extra logica |
| Reactietijd | afhankelijk van de lus | kort en voorspelbaar |
| CPU-tijd | verspild aan wachten | alleen bij gebeurtenissen |
| Complexiteit | eenvoudig | subtiel |

## 5. Hoe werkt een interrupt?

Het idee in vier stappen:

1. Een apparaat zet de aanvraaglijn (`irq`) hoog.
2. Zijn interrupts toegestaan (`IE` = 1), dan neemt de CPU tussen twee instructies de aanvraag aan. Hij bewaart het huidige adres (de PC) in het register `EPC` en de vlaggen in schaduwregisters. Hij zet `IE` uit (geen nieuwe interrupts tijdens de afhandeling) en springt naar een vast adres, de vector (hier `0x02`).
3. Op dat adres staat de interruptroutine (ISR). Die handelt het apparaat af en wist de aanvraag.
4. De instructie `RETI` zet de PC terug op `EPC`, herstelt de vlaggen en zet `IE` weer aan. Het hoofdprogramma gaat verder alsof er niets gebeurd is.

```text
 hoofdprogramma:  ... ADD ... ADDI ... [ BNE ]  ...
                                 │ irq!
                                 ▼
                       EPC = adres van BNE, vlaggen bewaard, naar 0x02
                       ISR:  registers bewaren ... werk doen ... registers terug
                       RETI → PC = EPC, vlaggen terug
                                 │
                                 ▼
                        [ BNE ] ...  (ziet dezelfde vlaggen als voor de interrupt)
```

### Wat de hardware bewaart en wat de software

De interrupt kan op elk moment tussen twee instructies komen. Het hoofdprogramma weet er niet van, dus alles wat de ISR verandert, moet hersteld worden.

De hardware bewaart de PC (in `EPC`) en de vlaggen Z, N, C en V. Dat kan niet in software: je kunt de vlaggen niet lezen en je moet nog steeds weten waar je was. De software (de ISR) bewaart de registers die ze gebruikt in het geheugen. In W8 zit daar een haak aan: om iets in het geheugen te zetten heb je een register met een adres nodig. Daarom reserveren we R6 voor de interruptroutine. Het hoofdprogramma mag R6 nooit gebruiken. De ISR laadt er een adres in, bewaart de andere registers die ze nodig heeft en gebruikt R6 vrij.

Zulke conventies zie je overal. Echte CPU's lossen het soms op met gebankte registers (een aparte set voor de ISR) of met een stapel.

### Latentie

De CPU neemt een aanvraag alleen aan het begin van een instructie aan (stap T0). In het slechtste geval moet hij dus eerst de lopende instructie afmaken (2 cycli), en het aannemen zelf kost 2 cycli (een tussenstap met een NOP). De eerste ISR-instructie wordt dus uiterlijk 4 cycli na de aanvraag opgehaald. Dat is de interruptlatentie.

## 6. De hardware

De uitbreiding bestaat uit vier delen:

1. een datapath met `EPC`, `IE` en schaduwvlaggen
2. een besturing die tussen instructies de aanvraag controleert en drie nieuwe instructies (`RETI`, `EI`, `DI`) kent
3. een apparatenblok (`mmio.v`) met RAM, UART, timer en GPIO
4. een nieuwe top die ze verbindt

De ALU, de decoder en de geheugens blijven hetzelfde. Kopieer ze naar `labs/cpu_irq/`.

<!-- COPY cpu/alu.v cpu_irq/alu.v -->
<!-- COPY cpu/idecode.v cpu_irq/idecode.v -->
<!-- COPY cpu/memories.v cpu_irq/memories.v -->
<!-- COPY cpu/asm_funcs.vh cpu_irq/asm_funcs.vh -->
<!-- COPY cpu/asm.py cpu_irq/asm.py -->

De nieuwe instructies zitten al sinds week 17 in `asm.py`: `RETI` (opcode `B`), `EI` (`C`) en `DI` (`D`).

### Datapath

Vergelijk dit met `datapath.v` van week 14. Nieuw zijn `epc`, `ie`, de schaduwvlaggen en de tak `int_enter`.

```verilog
// FILE: cpu_irq/datapath_i.v
// Het datapath: PC, instructieregister, registerbestand, ALU, vlaggen.
// Alle besturingssignalen komen van buiten (de besturingseenheid).
module datapath_i #(parameter VECTOR = 8'h02) (
  input        clk,
  input        rst_n,
  // besturingssignalen
  input        pc_inc,      // PC <= PC + 1
  input        pc_load,     // PC <= doel
  input        pc_src,      // doel: 0 = imm8 uit de instructie, 1 = register A
  input        ir_we,       // instructieregister laden
  input        reg_we,      // naar een register schrijven
  input        wa_r7,       // schrijf naar R7 in plaats van rd
  input        ra_sel,      // leespoort A: 0 = rs1, 1 = rd
  input        rb_sel,      // leespoort B: 0 = rs2, 1 = rd
  input  [1:0] b_sel,       // ALU-ingang B: 0 = register, 1 = imm8, 2 = off6
  input        alu_ir,      // ALU-bewerking uit de instructie (fn) i.p.v. alu_op
  input  [2:0] alu_op,
  input  [1:0] wb_sel,      // terugschrijven: 0 = ALU, 1 = geheugen, 2 = imm8, 3 = PC
  input        flags_we,
  // interrupts
  input        int_enter,   // neem een interrupt: bewaar PC en vlaggen, spring naar VECTOR
  input        reti,        // terug uit de interrupt
  input        ei,          // interrupts aan
  input        di,          // interrupts uit
  output       ie_out,      // zijn interrupts aan?
  // instructiegeheugen
  output [7:0]  imem_addr,
  input  [15:0] imem_dout,
  // datageheugen
  output [7:0]  dmem_addr,
  output [7:0]  dmem_wdata,
  input  [7:0]  dmem_rdata,
  // naar de besturingseenheid
  output [3:0]  op,
  output [2:0]  cond,
  output        flag_z,
  output        flag_n,
  output        flag_c,
  output        flag_v,
  // voor debuggen
  output [7:0]  pc_out,
  output [7:0]  r0, r1, r2, r3, r4, r5, r6, r7
);
  reg [7:0]  pc, epc;
  reg        ie;
  reg        sfz, sfn, sfc, sfv;       // bewaarde vlaggen
  reg [15:0] ir;
  reg        fz, fn_, fc, fv;
  reg [7:0]  r [0:7];

  wire [2:0] rd, rs1, rs2, fn;
  wire [7:0] imm8;
  wire [5:0] off6;
  idecode dec(ir, op, rd, rs1, rs2, fn, cond, imm8, off6);

  // leespoorten
  wire [7:0] rega = r[ra_sel ? rd : rs1];
  wire [7:0] regb = r[rb_sel ? rd : rs2];

  // ALU
  wire [7:0] alu_b = (b_sel == 2'd0) ? regb :
                     (b_sel == 2'd1) ? imm8 : {2'b00, off6};
  wire [7:0] y;
  wire       az, an, ac, av;
  alu #(8) u_alu(rega, alu_b, alu_ir ? fn : alu_op, y, az, an, ac, av);

  // terugschrijven
  wire [7:0] wdata = (wb_sel == 2'd0) ? y :
                     (wb_sel == 2'd1) ? dmem_rdata :
                     (wb_sel == 2'd2) ? imm8 : pc;
  wire [2:0] waddr = wa_r7 ? 3'd7 : rd;

  integer i;
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pc <= 8'h00; ir <= 16'hA000; epc <= 8'h00; ie <= 1'b0;
      fz <= 0; fn_ <= 0; fc <= 0; fv <= 0; sfz <= 0; sfn <= 0; sfc <= 0; sfv <= 0;
      for (i = 0; i < 8; i = i + 1) r[i] <= 8'h00;
    end else if (int_enter) begin
      // Interrupt: PC en vlaggen bewaren, springen, interrupts uit, geen instructie ophalen (NOP).
      epc <= pc;  pc <= VECTOR;  ie <= 1'b0;  ir <= 16'hA000;
      sfz <= fz;  sfn <= fn_;  sfc <= fc;  sfv <= fv;
    end else begin
      if (ir_we) ir <= imem_dout;
      if (reti) begin
        pc <= epc;  ie <= 1'b1;
        fz <= sfz;  fn_ <= sfn;  fc <= sfc;  fv <= sfv;
      end else begin
        if (pc_load)     pc <= pc_src ? rega : imm8;
        else if (pc_inc) pc <= pc + 8'd1;
        if (flags_we) begin fz <= az; fn_ <= an; fc <= ac; fv <= av; end
      end
      if (ei) ie <= 1'b1;
      if (di) ie <= 1'b0;
      if (reg_we) r[waddr] <= wdata;
    end

  assign ie_out = ie;
  assign imem_addr  = pc;
  assign dmem_addr  = y;
  assign dmem_wdata = regb;
  assign flag_z = fz;  assign flag_n = fn_;  assign flag_c = fc;  assign flag_v = fv;
  assign pc_out = pc;
  assign r0 = r[0]; assign r1 = r[1]; assign r2 = r[2]; assign r3 = r[3];
  assign r4 = r[4]; assign r5 = r[5]; assign r6 = r[6]; assign r7 = r[7];
endmodule
```

Let op de volgorde in het `always`-blok: bij `int_enter` gebeurt alleen het interruptwerk. De instructie die tegelijk uit het geheugen komt, wordt weggegooid (het IR krijgt een `NOP`), net als bij de flush in week 20.

### Besturing

```verilog
// FILE: cpu_irq/control_i.v
// De besturingseenheid: een controlegeheugen (control store) dat voor elke combinatie
// van (opcode, stap) een controlewoord oplevert. Stap 0 = ophalen, stap 1 = uitvoeren.
module control_i(
  input        clk,
  input        rst_n,
  input  [3:0] op,
  input  [2:0] cond,
  input        flag_z, flag_n, flag_c, flag_v,
  input        irq,         // een apparaat vraagt om aandacht
  input        ie,          // interrupts zijn toegestaan
  output       pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7,
  output       ra_sel, rb_sel, alu_ir, flags_we, mem_we,
  output [1:0] wb_sel, b_sel,
  output [2:0] alu_op,
  output       mem_rd,      // leesactie (voor apparaten waarvan lezen iets doet)
  output       int_enter, reti, ei, di,
  output       halted
);
  // Opcodes
  localparam OP_ALU = 4'h0, OP_LDI = 4'h1, OP_ADDI = 4'h2, OP_LD = 4'h3, OP_ST = 4'h4,
             OP_BCC = 4'h5, OP_CMP = 4'h6, OP_CMPI = 4'h7, OP_CALL = 4'h8, OP_JR = 4'h9,
             OP_RETI = 4'hB, OP_EI = 4'hC, OP_DI = 4'hD, OP_HALT = 4'hF;

  // Bitposities in het controlewoord
  localparam [23:0]
    F_PC_INC   = 24'h000001,
    F_PC_LOAD  = 24'h000002,
    F_PC_REG   = 24'h000004,
    F_IR_WE    = 24'h000008,
    F_REG_WE   = 24'h000010,
    F_WA_R7    = 24'h000020,
    F_RA_RD    = 24'h000040,
    F_RB_RD    = 24'h000080,
    F_ALU_IR   = 24'h000100,
    F_FLAGS    = 24'h000200,
    F_MEM_WE   = 24'h000400,
    F_COND     = 24'h000800,          // laad de PC alleen als de voorwaarde klopt
    F_WB_MEM   = 24'h001000,          // wb_sel = 1
    F_WB_IMM   = 24'h002000,          // wb_sel = 2
    F_WB_PC    = 24'h003000,          // wb_sel = 3
    F_B_IMM    = 24'h004000,          // b_sel = 1
    F_B_OFF    = 24'h008000,          // b_sel = 2
    F_ALU_SUB  = 24'h010000,          // alu_op = 1
    F_HALT     = 24'h080000,
    F_RETI     = 24'h100000,
    F_EI       = 24'h200000,
    F_DI       = 24'h400000,
    F_INT      = 24'h800000;

  reg t;                             // 0 = ophalen, 1 = uitvoeren
  reg halt_r;
  reg [23:0] cw;

  // Het controlegeheugen zelf: opcode en stap in, controlewoord uit.
  always_comb begin
    cw = 24'h0;
    if (!halt_r) begin
      if (t == 1'b0) cw = (irq && ie) ? F_INT : (F_PC_INC | F_IR_WE);   // ophalen, of een interrupt nemen
      else case (op)
        OP_ALU:  cw = F_ALU_IR | F_REG_WE | F_FLAGS;             // rd = rs1 <fn> rs2
        OP_LDI:  cw = F_REG_WE | F_WB_IMM;                       // rd = imm8
        OP_ADDI: cw = F_RA_RD | F_B_IMM | F_REG_WE | F_FLAGS;    // rd = rd + imm8
        OP_LD:   cw = F_B_OFF | F_REG_WE | F_WB_MEM;             // rd = mem[rs1 + off6]
        OP_ST:   cw = F_B_OFF | F_RB_RD | F_MEM_WE;              // mem[rs1 + off6] = rd
        OP_BCC:  cw = F_PC_LOAD | F_COND;                        // if cond: PC = imm8
        OP_CMP:  cw = F_ALU_SUB | F_FLAGS;                       // vlaggen van rs1 - rs2
        OP_CMPI: cw = F_RA_RD | F_B_IMM | F_ALU_SUB | F_FLAGS;   // vlaggen van rd - imm8
        OP_CALL: cw = F_PC_LOAD | F_REG_WE | F_WA_R7 | F_WB_PC;  // R7 = PC; PC = imm8
        OP_JR:   cw = F_PC_LOAD | F_PC_REG;                      // PC = rs1
        OP_RETI: cw = F_RETI;                                    // PC = EPC, interrupts weer aan
        OP_EI:   cw = F_EI;
        OP_DI:   cw = F_DI;
        OP_HALT: cw = F_HALT;
        default: cw = 24'h0;                                     // NOP en ongebruikte opcodes
      endcase
    end
  end

  // Voorwaarde-evaluatie
  reg cond_ok;
  always_comb begin
    case (cond)
      3'd0: cond_ok = 1'b1;              // AL  altijd
      3'd1: cond_ok = flag_z;                // EQ
      3'd2: cond_ok = ~flag_z;               // NE
      3'd3: cond_ok = flag_c;                // CS  (A >= B zonder teken na CMP)
      3'd4: cond_ok = ~flag_c;               // CC  (A <  B zonder teken)
      3'd5: cond_ok = flag_n ^ flag_v;           // LT  (met teken)
      3'd6: cond_ok = ~(flag_n ^ flag_v);        // GE  (met teken)
      default: cond_ok = flag_n;             // MI  negatief
    endcase
  end

  // Stap en halt-vlag
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin t <= 1'b0; halt_r <= 1'b0; end
    else if (!halt_r) begin
      t <= ~t;
      if (cw[19]) halt_r <= 1'b1;
    end

  assign pc_inc   = cw[0];
  assign pc_load  = cw[1] & (~cw[11] | cond_ok);
  assign pc_src   = cw[2];
  assign ir_we    = cw[3];
  assign reg_we   = cw[4];
  assign wa_r7    = cw[5];
  assign ra_sel   = cw[6];
  assign rb_sel   = cw[7];
  assign alu_ir   = cw[8];
  assign flags_we = cw[9];
  assign mem_we   = cw[10];
  assign wb_sel   = cw[13:12];
  assign b_sel    = cw[15:14];
  assign alu_op   = cw[18:16];
  assign int_enter = cw[23];
  assign reti      = cw[20];
  assign ei        = cw[21];
  assign di        = cw[22];
  assign mem_rd    = (t == 1'b1) && !halt_r && (op == OP_LD);
  assign halted    = halt_r;
endmodule
```

Wat is er veranderd?

- Het controlewoord is 24 bit breed (vier nieuwe signalen).
- Tijdens T0 kijkt de besturing naar `irq && ie`. Is dat waar, dan komt er geen ophaalstap maar `F_INT` (de interrupt).
- Er zijn drie nieuwe regels in het controlegeheugen: `RETI`, `EI` en `DI`.
- `mem_rd` is nieuw. Een apparaat als de UART-ontvanger moet weten dat zijn register gelezen wordt (om "ontvangen" te wissen), en voor een leesactie bestond tot nu toe geen signaal.

### De apparaten

```verilog
// FILE: cpu_irq/mmio.v
// Het datageheugen met apparaten (memory-mapped I/O).
//   0x00..0xEF  RAM
//   0xF0  UART data      schrijven: verzenden; lezen: ontvangen byte (wist 'ontvangen')
//   0xF1  UART status    bit 0 = zender bezig, bit 1 = byte ontvangen
//   0xF2  Timer herlaadwaarde   (0 = timer uit)
//   0xF3  Timer status   lezen: bit 0 = aanvraag; schrijven (willekeurige waarde): aanvraag wissen
//   0xF5  GPIO uit (bijvoorbeeld LED's)     0xF6  GPIO in (bijvoorbeeld schakelaars)
//   0xF7  Interrupt-aan   bit 0 = timer, bit 1 = UART ontvangen
module mmio #(parameter DIV = 16, parameter TDIV = 1, parameter DATA = "data.hex", parameter DLOAD = 0) (
  input        clk,
  input        rst_n,
  input        we,
  input        rd,
  input  [7:0] addr,
  input  [7:0] wdata,
  output reg [7:0] rdata,
  output       txd,
  input        rxd,
  input  [7:0] gpio_in,
  output reg [7:0] gpio_out,
  output       irq
);
  // ---- RAM ----
  wire [7:0] ram_dout;
  dmem #(DATA, DLOAD) ram(clk, we && (addr < 8'hF0), addr, wdata, ram_dout);

  // ---- UART zender: 1 startbit, 8 databits (laagste eerst), 1 stopbit ----
  reg [9:0]  tx_frame;
  reg [3:0]  tx_n;
  reg [15:0] tx_cnt;
  wire tx_busy = (tx_n != 0);
  assign txd = tx_busy ? tx_frame[0] : 1'b1;

  // ---- UART ontvanger, met een synchronizer voor de ingang (week 6) ----
  reg rxd_s1, rxd_s2;
  reg        rx_busy, rx_ready;
  reg [3:0]  rx_n;
  reg [15:0] rx_cnt;
  reg [7:0]  rx_shift, rx_data;

  // ---- Timer: telt 'tikken'. Een tik is TDIV klokcycli (TDIV = 1: elke cyclus; op een FPGA bijvoorbeeld 1 ms) ----
  reg [7:0]  t_reload, t_cnt;
  reg        t_pend;
  reg [15:0] t_pre;
  wire       t_tick = (TDIV <= 1) ? 1'b1 : (t_pre == TDIV - 1);

  reg [7:0] irq_en;

  assign irq = (t_pend & irq_en[0]) | (rx_ready & irq_en[1]);

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      tx_frame <= 10'h3FF; tx_n <= 0; tx_cnt <= 0;
      rxd_s1 <= 1; rxd_s2 <= 1; rx_busy <= 0; rx_ready <= 0; rx_n <= 0; rx_cnt <= 0; rx_shift <= 0; rx_data <= 0;
      t_reload <= 0; t_cnt <= 0; t_pend <= 0; t_pre <= 0; irq_en <= 0; gpio_out <= 0;
    end else begin
      // schrijfacties van de CPU
      if (we) case (addr)
        8'hF0: if (!tx_busy) begin tx_frame <= {1'b1, wdata, 1'b0}; tx_n <= 4'd10; tx_cnt <= DIV - 1; end
        8'hF2: t_reload <= wdata;
        8'hF3: t_pend <= 1'b0;
        8'hF5: gpio_out <= wdata;
        8'hF7: irq_en <= wdata;
        default: ;
      endcase

      // zender
      if (tx_busy && !(we && addr == 8'hF0)) begin
        if (tx_cnt == 0) begin
          tx_cnt <= DIV - 1;
          tx_frame <= {1'b1, tx_frame[9:1]};
          tx_n <= tx_n - 1;
        end else tx_cnt <= tx_cnt - 1;
      end

      // ontvanger
      rxd_s1 <= rxd; rxd_s2 <= rxd_s1;
      if (rd && addr == 8'hF0) rx_ready <= 1'b0;
      if (!rx_busy) begin
        if (!rxd_s2) begin rx_busy <= 1; rx_cnt <= DIV / 2; rx_n <= 0; end
      end else begin
        if (rx_cnt == 0) begin
          rx_cnt <= DIV - 1;
          if (rx_n == 0) begin
            if (rxd_s2) rx_busy <= 0;                       // valse start: afbreken
            rx_n <= 1;
          end else if (rx_n <= 8) begin
            rx_shift <= {rxd_s2, rx_shift[7:1]}; rx_n <= rx_n + 1;
          end else begin
            if (rxd_s2) begin rx_data <= rx_shift; rx_ready <= 1'b1; end
            rx_busy <= 0;
          end
        end else rx_cnt <= rx_cnt - 1;
      end

      // timer
      t_pre <= t_tick ? 16'd0 : t_pre + 16'd1;
      if (t_reload != 0) begin
        if (t_tick) begin
          if (t_cnt >= t_reload - 1) begin t_cnt <= 0; t_pend <= 1'b1; end
          else t_cnt <= t_cnt + 1;
        end
      end else t_cnt <= 0;
    end

  always_comb begin
    case (addr)
      8'hF0: rdata = rx_data;
      8'hF1: rdata = {6'b0, rx_ready, tx_busy};
      8'hF2: rdata = t_reload;
      8'hF3: rdata = {7'b0, t_pend};
      8'hF5: rdata = gpio_out;
      8'hF6: rdata = gpio_in;
      8'hF7: rdata = irq_en;
      default: rdata = (addr < 8'hF0) ? ram_dout : 8'h00;
    endcase
  end
endmodule
```

Dit stuk bevat de hele UART, de timer en de GPIO. Alles wat we wisten over registers, tellers, schuifregisters en synchronizers komt hier in één module samen.

### De CPU

```verilog
// FILE: cpu_irq/cpu_i.v
// W8 met apparaten en interrupts.
module cpu_i #(
  parameter PROG = "prog.hex", parameter LOAD = 1, parameter DIV = 16, parameter TDIV = 1,
  parameter DATA = "data.hex", parameter DLOAD = 0
) (
  input         clk,
  input         rst_n,
  output        halted,
  output [7:0]  pc_out,
  output [7:0]  r0, r1, r2, r3, r4, r5, r6, r7,
  output        flag_z, flag_n, flag_c, flag_v,
  output        txd,
  input         rxd,
  input  [7:0]  gpio_in,
  output [7:0]  gpio_out
);
  wire pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel, alu_ir, flags_we, mem_we, mem_rd;
  wire int_enter, reti, ei, di, ie, irq;
  wire [1:0] wb_sel, b_sel;
  wire [2:0] alu_op, cond;
  wire [3:0] op;
  wire [7:0] imem_addr, dmem_addr, dmem_wdata, dmem_rdata;
  wire [15:0] imem_dout;

  datapath_i dp(
    .clk(clk), .rst_n(rst_n),
    .pc_inc(pc_inc), .pc_load(pc_load), .pc_src(pc_src), .ir_we(ir_we),
    .reg_we(reg_we), .wa_r7(wa_r7), .ra_sel(ra_sel), .rb_sel(rb_sel),
    .b_sel(b_sel), .alu_ir(alu_ir), .alu_op(alu_op), .wb_sel(wb_sel), .flags_we(flags_we),
    .int_enter(int_enter), .reti(reti), .ei(ei), .di(di), .ie_out(ie),
    .imem_addr(imem_addr), .imem_dout(imem_dout),
    .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
    .op(op), .cond(cond),
    .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v),
    .pc_out(pc_out), .r0(r0), .r1(r1), .r2(r2), .r3(r3), .r4(r4), .r5(r5), .r6(r6), .r7(r7)
  );

  control_i ctl(
    .clk(clk), .rst_n(rst_n), .op(op), .cond(cond),
    .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v), .irq(irq), .ie(ie),
    .pc_inc(pc_inc), .pc_load(pc_load), .pc_src(pc_src), .ir_we(ir_we),
    .reg_we(reg_we), .wa_r7(wa_r7), .ra_sel(ra_sel), .rb_sel(rb_sel),
    .alu_ir(alu_ir), .flags_we(flags_we), .mem_we(mem_we),
    .wb_sel(wb_sel), .b_sel(b_sel), .alu_op(alu_op), .mem_rd(mem_rd),
    .int_enter(int_enter), .reti(reti), .ei(ei), .di(di), .halted(halted)
  );

  imem #(PROG, LOAD) im(imem_addr, imem_dout);
  mmio #(DIV, TDIV, DATA, DLOAD) io(clk, rst_n, mem_we, mem_rd, dmem_addr, dmem_wdata, dmem_rdata,
                 txd, rxd, gpio_in, gpio_out, irq);
endmodule
```

## 7. Programma's

### Een timer-interrupt tijdens een berekening

De hoofdlus telt 1 + 2 + ... + 200 (modulo 256 is dat 132). Intussen komt er elke 40 cycli een timer-interrupt die een teller in het geheugen ophoogt. Let op twee dingen. De routine bewaart R0 en gebruikt R6 als vrij register. En aan het eind verpest ze met opzet de vlaggen (`CMP R0, R0` zet Z). Zou de hardware de vlaggen niet herstellen, dan sprong de `BNE` in de hoofdlus soms niet en zou de uitkomst niet kloppen.

```text
; FILE: cpu_irq/timer.asm
; Een timer-interrupt tijdens een rekenlus. R6 is gereserveerd voor de interruptroutine.
; De hoofdlus telt 1+2+...+200 (modulo 256 = 132). De routine telt op adres 0x20 hoe vaak hij draaide.
        B    main
        .org 2
isr:    LDI  R6, 0xE0
        ST   R0, [R6+0]         ; R0 bewaren (R6 is van ons)
        LDI  R6, 0x20
        LD   R0, [R6]           ; teller in het geheugen
        ADDI R0, 1
        ST   R0, [R6]
        LDI  R6, 0xF3
        ST   R0, [R6]           ; schrijven naar 0xF3 wist de timer-aanvraag
        LDI  R6, 0xE0
        LD   R0, [R6+0]         ; R0 terug
        CMP  R0, R0             ; bewust de vlaggen verpesten (Z = 1), om te bewijzen dat ze hersteld worden
        RETI                    ; PC en vlaggen worden automatisch hersteld

main:   LDI  R1, 0              ; som
        LDI  R3, 200            ; teller
        LDI  R4, 0xF2
        LDI  R5, 40
        ST   R5, [R4]           ; timer: om de 40 klokcycli een aanvraag
        LDI  R4, 0xF7
        LDI  R5, 1
        ST   R5, [R4]           ; timer-interrupt toestaan
        EI
lus:    ADD  R1, R1, R3
        ADDI R3, -1
        BNE  lus                ; de vlaggen van ADDI blijven heel, ook als er een interrupt tussen komt
        DI
        HALT
```

De referentie is dezelfde berekening zonder timer:

```text
; FILE: cpu_irq/timer_uit.asm
; Dezelfde rekenlus, zonder timer: de referentie. Het resultaat moet gelijk zijn aan dat van timer.asm.
        B    main
        .org 2
isr:    RETI
main:   LDI  R1, 0
        LDI  R3, 200
lus:    ADD  R1, R1, R3
        ADDI R3, -1
        BNE  lus
        HALT
```

### UART met polling

De testbench sluit de zender aan op de ontvanger. Het programma verzendt "HI" en leest het terug.

```text
; FILE: cpu_irq/uart.asm
; Verzend "HI" via de UART en lees het terug (de testbench sluit de zender aan op de ontvanger).
; Gebruikt polling: wachten tot de zender vrij is of er een byte is ontvangen.
        LDI  R4, 0xF0           ; UART data
        LDI  R5, 0xF1           ; UART status
        LDI  R1, 0x48           ; 'H'
        CALL send
        LDI  R1, 0x49           ; 'I'
        CALL send
        LDI  R2, 0x30           ; hier komen de ontvangen bytes
        CALL recv
        ST   R1, [R2]
        ADDI R2, 1
        CALL recv
        ST   R1, [R2]
        HALT

send:   LD   R0, [R5]           ; status
        LDI  R3, 1
        AND  R0, R0, R3         ; bit 0 = zender bezig
        BNE  send               ; wacht tot de zender vrij is
        ST   R1, [R4]           ; verzenden
        RET

recv:   LD   R0, [R5]
        LDI  R3, 2
        AND  R0, R0, R3         ; bit 1 = byte ontvangen
        BEQ  recv
        LD   R1, [R4]           ; lezen wist de 'ontvangen'-vlag
        RET
```

### UART met interrupt

De ontvanger vraagt een interrupt aan als er een byte binnen is. De routine zet de byte in een buffer. De hoofdlus wacht tot er drie bytes zijn.

```text
; FILE: cpu_irq/uart_irq.asm
; Ontvang bytes via een interrupt. De routine zet elke ontvangen byte in een buffer vanaf 0x30
; en telt op adres 0x21. De hoofdlus wacht tot er 3 bytes binnen zijn.
        B    main
        .org 2
isr:    LDI  R6, 0xE0
        ST   R0, [R6+0]         ; R0 en R1 bewaren
        ST   R1, [R6+1]
        LDI  R6, 0xF0
        LD   R0, [R6]           ; de ontvangen byte (wist ook de aanvraag)
        LDI  R6, 0x21
        LD   R1, [R6]           ; aantal tot nu toe
        ST   R0, [R1+0x30]      ; buffer[aantal] = byte
        ADDI R1, 1
        ST   R1, [R6]           ; aantal verhogen
        LDI  R6, 0xE0
        LD   R0, [R6+0]
        LD   R1, [R6+1]
        RETI

main:   LDI  R4, 0xF7
        LDI  R5, 2
        ST   R5, [R4]           ; UART-ontvangst-interrupt toestaan
        EI
        LDI  R2, 0x21
wacht:  LD   R3, [R2]           ; hoofdlus: kijk hoeveel er binnen zijn
        CMPI R3, 3
        BCC  wacht              ; minder dan 3: doorgaan met wachten
        DI
        HALT
```

### Een knipperlicht

De hoofdlus doet niets (`B slaap`). Al het werk gebeurt in de interruptroutine: bit 0 van de GPIO-uitgang omdraaien.

```text
; FILE: cpu_irq/blink.asm
; Knipperlicht: de timer-interrupt wisselt bit 0 van de GPIO-uitgang (een LED). De hoofdlus doet niets.
        B    main
        .org 2
isr:    LDI  R6, 0xE0
        ST   R0, [R6+0]         ; R0 bewaren
        LDI  R6, 0xF5
        LD   R0, [R6]           ; huidige LED-toestand
        LDI  R6, 1
        XOR  R0, R0, R6         ; bit 0 omkeren
        LDI  R6, 0xF5
        ST   R0, [R6]           ; terug naar de LED
        LDI  R6, 0xF3
        ST   R0, [R6]           ; timer-aanvraag wissen
        LDI  R6, 0xE0
        LD   R0, [R6+0]         ; R0 terug
        RETI

main:   LDI  R4, 0xF2
        LDI  R5, 100
        ST   R5, [R4]           ; elke 100 cycli een tik
        LDI  R4, 0xF7
        LDI  R5, 1
        ST   R5, [R4]           ; timer-interrupt aan
        EI
slaap:  B    slaap              ; de hoofdlus wacht eeuwig; alles gebeurt in de interruptroutine
```

## 8. Verificatie

Drie scenario's tegelijk, elk op een eigen CPU:

- A. De timer-rekenlus tegen de referentie zonder timer. Beide moeten 132 opleveren, R0 moet hersteld zijn en de routine moet echt gedraaid hebben (in de testrun 74 keer).
- B. UART-polling. De testbench bevat een onafhankelijke UART-ontvanger die de lijn afluistert en de frames decodeert. Beide kanten (de ontvanger van de CPU en die van de testbench) moeten "H" en "I" zien.
- C. UART-interrupt. De testbench zendt drie bytes met onregelmatige tussenpozen en de CPU zet ze in een buffer.

```verilog
// FILE: cpu_irq/tb_irq.v
// Test van interrupts en apparaten: timer, UART met polling, UART met interrupt.
module tb_irq;
  localparam DIV = 16;
  reg clk = 0, rst_n = 0;
  integer fouten = 0, cycli, k;

  // --- A: timer-interrupt tegenover dezelfde berekening zonder interrupts ---
  wire ha, hb, ta, tb_;
  wire [7:0] a_r0, a_r1, a_r3, b_r0, b_r1, b_r3;
  cpu_i #("timer.hex", 1, DIV) ca(.clk(clk), .rst_n(rst_n), .halted(ha), .r0(a_r0), .r1(a_r1), .r3(a_r3),
                                  .rxd(1'b1), .gpio_in(8'd0));
  cpu_i #("timer_uit.hex", 1, DIV) cb(.clk(clk), .rst_n(rst_n), .halted(hb), .r0(b_r0), .r1(b_r1), .r3(b_r3),
                                      .rxd(1'b1), .gpio_in(8'd0));

  // --- B: UART met polling, zender aangesloten op eigen ontvanger ---
  wire hc, txd_c;
  cpu_i #("uart.hex", 1, DIV) cc(.clk(clk), .rst_n(rst_n), .halted(hc), .txd(txd_c), .rxd(txd_c), .gpio_in(8'd0));

  // --- C: UART-ontvangst met interrupt, de testbench zendt de bytes ---
  wire hd;
  reg  rxd_d = 1;
  cpu_i #("uart_irq.hex", 1, DIV) cd(.clk(clk), .rst_n(rst_n), .halted(hd), .rxd(rxd_d), .gpio_in(8'd0));

  always #5 clk = ~clk;

  // Een onafhankelijke UART-ontvanger voor de zenderlijn van B, om de frames te controleren.
  reg [7:0] gezien [0:7];
  integer n_gezien = 0;
  initial begin : monitor_tx
    reg [7:0] b;
    integer i;
    forever begin
      @(negedge txd_c);                         // begin van een startbit
      repeat (DIV + DIV / 2) @(posedge clk);    // naar het midden van databit 0
      for (i = 0; i < 8; i = i + 1) begin
        b[i] = txd_c;
        repeat (DIV) @(posedge clk);
      end
      if (txd_c !== 1'b1) begin fouten = fouten + 1; $display("FAIL: geen stopbit"); end
      gezien[n_gezien] = b; n_gezien = n_gezien + 1;
    end
  end

  // Bytes verzenden naar de ontvanger van C
  task stuur(input [7:0] b);
    integer i;
    begin
      rxd_d = 0; repeat (DIV) @(posedge clk);                 // startbit
      for (i = 0; i < 8; i = i + 1) begin rxd_d = b[i]; repeat (DIV) @(posedge clk); end
      rxd_d = 1; repeat (DIV) @(posedge clk);                 // stopbit
    end
  endtask

  initial begin
    #22 rst_n = 1;
    fork
      begin : zenden
        repeat (300) @(posedge clk);
        stuur(8'h41);
        repeat (200) @(posedge clk);
        stuur(8'h42);
        repeat (37) @(posedge clk);
        stuur(8'h43);
      end
    join_none
    cycli = 0;
    while (!(ha && hb && hc && hd) && cycli < 200000) begin @(negedge clk); cycli = cycli + 1; end
    if (cycli >= 200000) begin fouten = fouten + 1; $display("FAIL: niet alles stopte (a=%b b=%b c=%b d=%b)", ha, hb, hc, hd); end

    // A: de hoofdberekening is onaangetast door de interrupts
    $display("timer: ISR draaide %0d keer", ca.io.ram.mem[8'h20]);
    if (a_r1 !== 8'd132 || b_r1 !== 8'd132) begin fouten = fouten + 1; $display("FAIL A: R1 = %0d / %0d", a_r1, b_r1); end
    if (a_r3 !== 8'd0 || b_r3 !== 8'd0)     begin fouten = fouten + 1; $display("FAIL A: R3"); end
    if (a_r0 !== 8'd0 || b_r0 !== 8'd0)     begin fouten = fouten + 1; $display("FAIL A: R0 niet hersteld: %0d", a_r0); end
    if (ca.io.ram.mem[8'h20] < 8'd10)        begin fouten = fouten + 1; $display("FAIL A: te weinig interrupts"); end
    if (cb.io.ram.mem[8'h20] !== 8'd0)       begin fouten = fouten + 1; $display("FAIL A: referentie kreeg interrupts"); end

    // B: de frames op de lijn zijn 'H' en 'I', en de ontvanger heeft ze ook gezien
    if (n_gezien !== 2 || gezien[0] !== 8'h48 || gezien[1] !== 8'h49) begin fouten = fouten + 1; $display("FAIL B: lijn %0d bytes: %h %h", n_gezien, gezien[0], gezien[1]); end
    if (cc.io.ram.mem[8'h30] !== 8'h48 || cc.io.ram.mem[8'h31] !== 8'h49) begin
      fouten = fouten + 1; $display("FAIL B: ontvangen %h %h", cc.io.ram.mem[8'h30], cc.io.ram.mem[8'h31]);
    end

    // C: drie bytes via interrupts in de buffer
    if (cd.io.ram.mem[8'h21] !== 8'd3) begin fouten = fouten + 1; $display("FAIL C: aantal = %0d", cd.io.ram.mem[8'h21]); end
    if (cd.io.ram.mem[8'h30] !== 8'h41 || cd.io.ram.mem[8'h31] !== 8'h42 || cd.io.ram.mem[8'h32] !== 8'h43) begin
      fouten = fouten + 1; $display("FAIL C: buffer %h %h %h", cd.io.ram.mem[8'h30], cd.io.ram.mem[8'h31], cd.io.ram.mem[8'h32]);
    end

    if (fouten == 0) $display("PASS: timer-interrupt (transparant), UART-polling en UART-interrupt werken");
    $finish;
  end
endmodule
```

En het knipperlicht:

```verilog
// FILE: cpu_irq/tb_blink.v
module tb_blink;
  reg clk = 0, rst_n = 0;
  wire halted, txd;
  wire [7:0] led;
  integer wissels = 0, fouten = 0, cyc = 0;
  reg [7:0] vorige = 0;
  cpu_i #("blink.hex", 1, 16) dut(.clk(clk), .rst_n(rst_n), .halted(halted), .txd(txd), .rxd(1'b1), .gpio_in(8'd0), .gpio_out(led));
  always #5 clk = ~clk;
  always @(posedge clk) begin
    cyc = cyc + 1;
    if (rst_n && led !== vorige) begin
      wissels = wissels + 1;
      if ((led ^ vorige) !== 8'd1) begin fouten = fouten + 1; $display("FAIL: meer dan bit 0 veranderde: %b -> %b", vorige, led); end
      vorige = led;
    end
  end
  initial begin
    #22 rst_n = 1;
    repeat (5000) @(posedge clk);
    // Elke ~100 cycli een wissel: in 5000 cycli ongeveer 40 tot 50.
    $display("LED wisselde %0d keer in 5000 cycli", wissels);
    if (wissels < 35 || wissels > 52) begin fouten = fouten + 1; $display("FAIL: onverwacht aantal wissels"); end
    if (halted) begin fouten = fouten + 1; $display("FAIL: CPU stopte"); end
    if (fouten == 0) $display("PASS: de LED knippert via de timer-interrupt terwijl de hoofdlus niets doet");
    $finish;
  end
endmodule
```

### De test testen

Verwijder de herstelregel voor de vlaggen in `datapath_i.v` (`fz <= sfz; ...` bij `reti`). Draai `tb_irq.v` opnieuw. Je ziet:

```text
FAIL A: R1 = 36 / 132
FAIL A: R3
```

De berekening is verpest, omdat een interrupt tussen `ADDI` en `BNE` de Z-vlag omdraaide. Een eerste versie van deze test ving dit niet op: de routine liet de Z-vlag toevallig in een toestand die de hoofdlus niet stoorde. Pas toen de routine de vlaggen met opzet verpestte, werd de fout zichtbaar. Dat is een algemene les over het testen van timingafhankelijke fouten: een test moet het probleem actief uitlokken, anders slaagt hij door geluk.

## 9. Lab

1. Draai `tb_irq.v` en `tb_blink.v`.
2. Haal de `CMP R0, R0` uit `timer.asm`, assembleer opnieuw en draai de test met de gesaboteerde hardware (zonder herstel van de vlaggen). Slaagt hij nu wel? Wat leert dit je?
3. Open een golfvorm van `tb_blink.v` en meet de tijd tussen twee wissels. Hoe verhoudt die zich tot de herlaadwaarde 100?
4. Verander in `blink.asm` de herlaadwaarde en bereken de verwachte knipperfrequentie bij een klok van 1 MHz.
5. Laat de ISR in `uart_irq.asm` elke ontvangen byte ook meteen terugsturen (echo).

## 10. Oefeningen

1. Bereken `DIV` voor 115 200 baud op een klok van 50 MHz. Wat is de relatieve fout?
2. Hoe lang duurt het verzenden van één byte (10 bits) op 9600 baud? En hoeveel bytes per seconde is dat maximaal?
3. De timer-ISR in `timer.asm` kost ongeveer 26 cycli. Welk deel van de CPU-tijd gaat naar de ISR bij een timerperiode van 40 cycli? Welke periode kies je voor maximaal 5 %?
4. Waarom bewaart de hardware de vlaggen, terwijl de ISR de registers zelf moet bewaren?
5. Een 16-bit teller wordt door een ISR opgehoogd (twee bytes, laag en hoog). Het hoofdprogramma leest eerst het lage byte en dan het hoge byte. Beschrijf een situatie waarin het hoofdprogramma een foute waarde leest en hoe je dat oplost (atomisch lezen).
6. Wat gebeurt er als de ISR vergeet de timeraanvraag te wissen?
7. Waarom wordt `IE` bij het aannemen van een interrupt automatisch uitgezet? Wat is er mis met geneste interrupts zonder voorzorgen?
8. Uitdaging: voeg een tweede interruptbron toe met een eigen vector (bijvoorbeeld de UART op `0x04`). Wat verandert er in de besturing en in het datapath?
9. Uitdaging: maak een kleine monitor, een programma dat bytes via de UART ontvangt en als commando uitvoert (bijvoorbeeld 'L' = zet de LED aan, 'D' = LED uit).

## 11. Antwoorden

1. DIV = 50 000 000 / 115 200 = 434,03, dus 434. De werkelijke baudrate is 50 000 000 / 434 = 115 207, een fout van 0,006 %.
2. 10 bits / 9600 = 1,04 ms, dus maximaal ongeveer 960 bytes per seconde.
3. 26 / 40 = 65 %. Voor 5 % moet de periode minstens 26 / 0,05 = 520 cycli zijn.
4. W8 heeft geen instructie om de vlaggen te lezen of te schrijven, dus software kan ze niet bewaren. De registers kan de ISR wel veiligstellen met `ST` en `LD`. Het hoofdprogramma weet niet wanneer de interrupt komt. De ISR veroorzaakt de verstoring en is dus verantwoordelijk voor het herstel, maar voor de vlaggen kan alleen de hardware dat doen.
5. De ISR kan tussen het lezen van het lage en het hoge byte komen. Rolt het lage byte net om van 0xFF naar 0x00 en is het hoge byte nog niet opgehoogd (of juist wel), dan krijg je een mengsel. Bijvoorbeeld: 0x01FF wordt eerst als laag byte 0xFF gelezen, dan komt de ISR (nu 0x0200) en daarna lees je hoog = 0x02. Je krijgt dan 0x02FF. De oplossing is interrupts tijdelijk uitzetten (`DI`) tijdens het lezen en daarna weer aan (`EI`), of de waarde twee keer lezen tot hij consistent is.
6. De aanvraag blijft staan, en zodra `RETI` interrupts weer aanzet, begint de ISR opnieuw. De CPU zit vast in de ISR en het hoofdprogramma komt niet meer aan bod.
7. Zonder die voorzorg kan de ISR zelf worden onderbroken voordat ze `EPC` en de bewaarde vlaggen heeft veiliggesteld. Met één `EPC` zou de tweede interrupt de eerste overschrijven. Geneste interrupts vragen een stapel voor de teruggekeerde toestanden of een eigen `EPC` per niveau.
8. Het datapath krijgt een vectorkeuze (welke bron?) en de besturing moet kiezen welke aanvraag voorrang heeft (prioriteit) en welk adres naar de PC gaat. Voor de ISR zelf kun je dan twee routines schrijven in plaats van in één routine uit te zoeken wie de aanvraag deed.
9. Dit is een open opdracht. De aanpak: interrupt bij ontvangst, de ISR schrijft de byte naar een buffer en de hoofdlus leest de buffer uit, vergelijkt met `CMPI` en voert het commando uit.

## 12. Zelftest

1. Wat is memory-mapped I/O?
2. Wat is het verschil tussen polling en een interrupt?
3. Wat bewaart de hardware bij een interrupt en wat de software?
4. Wat doet `RETI`?
5. Waarom samplet de UART-ontvanger in het midden van een bit?

Antwoorden: (1) Apparaatregisters die op geheugenadressen zitten en met gewone lees- en schrijfinstructies worden gebruikt. (2) Bij polling kijkt de CPU zelf steeds, bij een interrupt meldt het apparaat zich. (3) De hardware bewaart de PC en de vlaggen, de software de registers die de ISR gebruikt. (4) Het herstelt PC en vlaggen en zet interrupts weer aan. (5) Daar is de lijn het stabielst. Aan de randen kunnen kleine timingfouten en ruis de waarde verkeerd laten lezen.

## 13. Verder lezen

- Harris en Harris, 8.5 (I/O-systemen) en hoofdstuk 6.7 (interrupts en uitzonderingen).
- Het datablad van een echte UART, bijvoorbeeld de 16550, om te zien hoeveel mogelijkheden er bijkomen (FIFO's, pariteit).
- De RISC-V *privileged specification*, het hoofdstuk over traps: hoe een moderne CPU interrupts, uitzonderingen en privilegeniveaus regelt.

---

> **Fase 5 is af.** Je kent nu vier architecturen (register, stack, TTA en pipeline), geheugenhiërarchie en sprongvoorspelling, en je CPU heeft een buitenwereld met interrupts. Fase 6 brengt het naar echte hardware: eerst op een FPGA, dan op een printplaat en uiteindelijk op silicium.

Volgende week: je CPU draait nu in de simulator. Tijd om hem op echte chips te laten draaien: de FPGA.
