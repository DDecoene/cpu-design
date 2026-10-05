---
title: "Week 24 · Synthese, timing en optimalisatie"
---

<p class="subtitle">Fase 6 · Van code naar chip · ongeveer 14 uur</p>

# Week 24: Synthese, timing en optimalisatie

## Wat je na deze week kunt

- een synthese- en place-and-route-rapport lezen: gebruik, maximale frequentie en kritiek pad
- uitleggen wat setup, hold, slack en timing closure zijn
- uit een rapport afleiden waar een ontwerp groot of langzaam is
- een ontwerp aanpassen voor een FPGA (blok-RAM, synchrone uitlezing) en het effect meten
- met een gate-level simulatie bewijzen dat de synthese het gedrag niet veranderd heeft
- een ontwerp vergelijken op tijd (cycli gedeeld door frequentie) en niet alleen op cycli

## 1. Wat vertelt de tool?

Aan het eind van week 23 had onze CPU de volgende kenmerken (gemeten met Yosys en nextpnr op een iCE40 HX8K):

| Gegeven | W8I |
|---------|-----|
| LUT4 | 3 202 |
| Flipflops | 2 148 |
| Gebruikte logische elementen | 5 297 van 7 680 (68 %) |
| Maximale frequentie | 34,3 MHz |

Dat is veel voor een eenvoudige 8-bit CPU. Een goede ingenieur vraagt zich nu af waar die ruimte naartoe gaat. Het antwoord staat in de details van het rapport.

### Uitvoer van de synthese

Aan het eind geeft Yosys een telling van de gebruikte cellen:

```text
      116   SB_CARRY          ← carry-ketens (de opteller)
     1920   SB_DFFE           ← 1920 flipflops met enable
      188   SB_DFFER
     3202   SB_LUT4
```

Het getal 1920 springt eruit. Reken maar: 240 bytes RAM × 8 bit = 1920. Het datageheugen is helemaal uit losse flipflops gebouwd. En naast die 1920 flipflops komt er voor het lezen ook nog een 240-op-1 multiplexer per bit bij, ongeveer 2 500 LUT's.

### Waarom?

In `dmem` lees je het geheugen asynchroon: `assign dout = mem[addr];`. De data verschijnt zodra het adres verandert. Het blok-RAM van een FPGA werkt anders: dat is synchroon. Het adres wordt bij een klokflank vastgelegd en de data staat een klokperiode later klaar. Een asynchroon geheugen past dus niet op blok-RAM, en de tool maakt het van gewone flipflops en multiplexers.

Voor FPGA's geldt: wil je blok-RAM, schrijf dan een geheugen met een synchrone uitlezing (`dout <= mem[addr]` binnen `always @(posedge clk)`).

## 2. Timing: waarom de klok niet sneller kan

Alle digitale schakelingen die we gebouwd hebben, volgen één regel (week 5):

```text
 T_klok  ≥  t_clk→Q  +  t_logica  +  t_routering  +  t_setup
```

Die regel moet gelden voor elke weg tussen twee flipflops. De langzaamste weg is het kritieke pad en bepaalt de maximale klokfrequentie. De tool schrijft het uit.

### Begrippen

| Begrip | Betekenis |
|--------|-----------|
| Setup time | hoe lang een signaal voor de klokflank stabiel moet zijn |
| Hold time | hoe lang het na de klokflank stabiel moet blijven |
| Slack | marge: de klokperiode min de padvertraging. Positief is goed, negatief betekent dat het pad te langzaam is |
| Timing closure | alle paden hebben slack ≥ 0 |
| Constraint | de eis die jij aan de tool geeft, bijvoorbeeld "27 MHz" (`--freq 27`) |

nextpnr krijgt de gewenste frequentie als doel en meldt `PASS` of `FAIL`:

```text
Max frequency for clock 'clk': 34.29 MHz (PASS at 27.00 MHz)
```

### Het kritieke pad lezen

Het rapport bevat het pad stap voor stap. De analyse van W8I:

| Onderdeel van het pad | Tijd |
|-----------------------|-----:|
| clock-to-Q van de eerste flipflop | 0,54 ns |
| logica: 18 LUT's achter elkaar | 6,12 ns |
| routering tussen die LUT's | 22,02 ns |
| totaal | ca. 28,7 ns → 34,8 MHz |

Hieruit volgen twee lessen.

1. Op een FPGA is routering de grote speler: 78 % van de tijd. De draden en schakelaars tussen de LUT's zijn veel langzamer dan de LUT's zelf. Een ontwerp met minder LUT's op het pad (en minder fanout) is dus sneller, en een kleiner ontwerp is ook korter bedraad.
2. Het pad is 18 LUT's diep. De weg loopt van de toestand van de besturing via het registerbestand (de multiplexer die `regb` kiest) en de ALU naar de vlaggen. Het is hetzelfde kritieke pad dat we in week 14 op papier vonden: registers lezen, ALU, terugschrijven. Pipelining (week 20) knipt het in stukken.

## 3. De oplossing: W8F

We willen het datageheugen in blok-RAM, met synchrone uitlezing. De apparaatregisters (UART, timer en GPIO) laten we op dezelfde manier uitlezen, zodat de CPU één regel heeft: de data is een klokperiode na het adres beschikbaar. En een `LD` moet daar rekening mee houden: drie stappen in plaats van twee.

De CPU heet W8F (F voor FPGA). Alles blijft hetzelfde, behalve drie bestanden. Kopieer eerst de rest (let op: het gaat om bestanden uit week 14 tot en met 23).

<!-- COPY cpu/memories.v cpu_fpga/memories.v -->
<!-- COPY cpu_irq/alu.v cpu_fpga/alu.v -->
<!-- COPY cpu_irq/idecode.v cpu_fpga/idecode.v -->
<!-- COPY cpu_irq/datapath_i.v cpu_fpga/datapath_i.v -->
<!-- COPY cpu_irq/control_i.v cpu_fpga/control_i.v -->
<!-- COPY cpu_irq/mmio.v cpu_fpga/mmio.v -->
<!-- COPY cpu_irq/cpu_i.v cpu_fpga/cpu_i.v -->
<!-- COPY cpu_irq/fpga_top.v cpu_fpga/fpga_top.v -->
<!-- COPY cpu_irq/asm.py cpu_fpga/asm.py -->
<!-- COPY cpu_irq/hello.asm cpu_fpga/hello.asm -->
<!-- COPY cpu_irq/timer.asm cpu_fpga/timer.asm -->
<!-- COPY cpu_irq/timer_uit.asm cpu_fpga/timer_uit.asm -->
<!-- COPY cpu_irq/uart.asm cpu_fpga/uart.asm -->
<!-- COPY cpu_irq/uart_irq.asm cpu_fpga/uart_irq.asm -->
<!-- COPY cpu_irq/blink.asm cpu_fpga/blink.asm -->
<!-- COPY cpu_irq/fpga_flow.sh cpu_fpga/fpga_flow.sh -->
<!-- COPY cpu/sum.asm cpu_fpga/sum.asm -->
<!-- COPY cpu/mul.asm cpu_fpga/mul.asm -->
<!-- COPY cpu/sort.asm cpu_fpga/sort.asm -->
<!-- COPY cpu/primes.asm cpu_fpga/primes.asm -->
<!-- COPY cpu/gcd.asm cpu_fpga/gcd.asm -->
<!-- COPY cpu/calls.asm cpu_fpga/calls.asm -->

### Het datageheugen met synchrone uitlezing

```verilog
// FILE: cpu_fpga/memories_f.v
// Datageheugen met synchrone uitlezing: de data verschijnt een klokperiode na het adres.
// Zo kan een synthesetool het in een blok-RAM van de FPGA onderbrengen.
module dmem_s #(parameter FILE = "data.hex", parameter LOAD = 0) (
  input            clk,
  input            we,
  input      [7:0] addr,
  input      [7:0] din,
  output reg [7:0] dout
);
  reg [7:0] mem [0:255];
  integer i;
  initial begin
    if (LOAD) $readmemh(FILE, mem);
    else for (i = 0; i < 256; i = i + 1) mem[i] = 8'h00;
  end
  always @(posedge clk) begin
    if (we) mem[addr] <= din;
    dout <= mem[addr];
  end
endmodule
```

Dit is het hele geheim: de uitlezing zit binnen het klokgestuurde blok. Yosys herkent het patroon en gebruikt een `SB_RAM40_4K`, een ingebouwd geheugenblok.

### De besturing: LD in drie stappen

Voor de rest is dit `control_i.v` van week 22. Het verschil is dat de toestand `t` (1 bit) `st` (2 bits) wordt, en dat `LD` drie stappen krijgt:

| Stap | Wat gebeurt er |
|------|----------------|
| 0 | ophalen |
| 1 | het adres wordt aan het geheugen aangeboden en aan het eind van deze stap legt het geheugen de data vast |
| 2 | het gelezen woord gaat naar het register |

```verilog
// FILE: cpu_fpga/control_f.v
// Besturing voor de FPGA-vriendelijke W8F. Zelfde controlegeheugen als control_i, maar het datageheugen
// geeft zijn gegevens pas een klokperiode na het adres (blok-RAM). Daarom heeft LD een derde stap.
module control_f(
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

  reg [1:0] st;                      // 0 = ophalen, 1 = uitvoeren, 2 = LD afronden
  wire t = (st != 2'd0);
  reg halt_r;
  reg [23:0] cw;

  // Het controlegeheugen zelf: opcode en stap in, controlewoord uit.
  always_comb begin
    cw = 24'h0;
    if (!halt_r) begin
      if (st == 2'd0) cw = (irq && ie) ? F_INT : (F_PC_INC | F_IR_WE);   // ophalen, of een interrupt nemen
      else if (st == 2'd2) cw = F_B_OFF | F_REG_WE | F_WB_MEM;            // LD, stap 3: het gelezen woord naar het register
      else case (op)
        OP_ALU:  cw = F_ALU_IR | F_REG_WE | F_FLAGS;             // rd = rs1 <fn> rs2
        OP_LDI:  cw = F_REG_WE | F_WB_IMM;                       // rd = imm8
        OP_ADDI: cw = F_RA_RD | F_B_IMM | F_REG_WE | F_FLAGS;    // rd = rd + imm8
        OP_LD:   cw = F_B_OFF;                                   // rd = mem[rs1 + off6]: adres aanbieden, lezen volgt in stap 3
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
    if (!rst_n) begin st <= 2'd0; halt_r <= 1'b0; end
    else if (!halt_r) begin
      case (st)
        2'd0:    st <= 2'd1;
        2'd1:    st <= (op == OP_LD) ? 2'd2 : 2'd0;
        default: st <= 2'd0;
      endcase
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
  assign mem_rd    = (st == 2'd1) && !halt_r && (op == OP_LD);
  assign halted    = halt_r;
endmodule
```

### De apparaten: ook een klokperiode vertraging

Het RAM geeft zijn data een periode later, dus moeten de apparaatregisters dat ook doen. Anders weet de CPU niet wanneer een lezing geldig is. De multiplexer die kiest tussen RAM en apparaat gebruikt het adres uit de vorige periode.

```verilog
// FILE: cpu_fpga/mmio_f.v
// Het datageheugen met apparaten (memory-mapped I/O).
//   0x00..0xEF  RAM
//   0xF0  UART data      schrijven: verzenden; lezen: ontvangen byte (wist 'ontvangen')
//   0xF1  UART status    bit 0 = zender bezig, bit 1 = byte ontvangen
//   0xF2  Timer herlaadwaarde   (0 = timer uit)
//   0xF3  Timer status   lezen: bit 0 = aanvraag; schrijven (willekeurige waarde): aanvraag wissen
//   0xF5  GPIO uit (bijvoorbeeld LED's)     0xF6  GPIO in (bijvoorbeeld schakelaars)
//   0xF7  Interrupt-aan   bit 0 = timer, bit 1 = UART ontvangen
module mmio_f #(parameter DIV = 16, parameter TDIV = 1, parameter DATA = "data.hex", parameter DLOAD = 0) (
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
  dmem_s #(DATA, DLOAD) ram(clk, we && (addr < 8'hF0), addr, wdata, ram_dout);   // blok-RAM: synchroon lezen

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

  // Lezen van de apparaten wordt, net als het RAM, een klokperiode vastgehouden.
  reg [7:0] io_comb, io_q;
  reg       ram_sel_q;
  always_comb begin
    case (addr)
      8'hF0: io_comb = rx_data;
      8'hF1: io_comb = {6'b0, rx_ready, tx_busy};
      8'hF2: io_comb = t_reload;
      8'hF3: io_comb = {7'b0, t_pend};
      8'hF5: io_comb = gpio_out;
      8'hF6: io_comb = gpio_in;
      8'hF7: io_comb = irq_en;
      default: io_comb = 8'h00;
    endcase
  end
  always @(posedge clk) begin
    io_q <= io_comb;
    ram_sel_q <= (addr < 8'hF0);
  end
  always_comb rdata = ram_sel_q ? ram_dout : io_q;
endmodule
```

### De CPU en het toplevel

```verilog
// FILE: cpu_fpga/cpu_f.v
// W8F: de FPGA-vriendelijke W8I. Datageheugen in blok-RAM, LD kost 3 cycli.
module cpu_f #(
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

  control_f ctl(
    .clk(clk), .rst_n(rst_n), .op(op), .cond(cond),
    .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v), .irq(irq), .ie(ie),
    .pc_inc(pc_inc), .pc_load(pc_load), .pc_src(pc_src), .ir_we(ir_we),
    .reg_we(reg_we), .wa_r7(wa_r7), .ra_sel(ra_sel), .rb_sel(rb_sel),
    .alu_ir(alu_ir), .flags_we(flags_we), .mem_we(mem_we),
    .wb_sel(wb_sel), .b_sel(b_sel), .alu_op(alu_op), .mem_rd(mem_rd),
    .int_enter(int_enter), .reti(reti), .ei(ei), .di(di), .halted(halted)
  );

  imem #(PROG, LOAD) im(imem_addr, imem_dout);
  mmio_f #(DIV, TDIV, DATA, DLOAD) io(clk, rst_n, mem_we, mem_rd, dmem_addr, dmem_wdata, dmem_rdata,
                 txd, rxd, gpio_in, gpio_out, irq);
endmodule
```

```verilog
// FILE: cpu_fpga/fpga_top_f.v
// Het toplevel voor een FPGA-bord: klok, een resetknop, LED's en een seriële poort.
// De LED's op veel borden zijn 'actief laag' (0 = aan), vandaar led_n.
module fpga_top_f #(
  parameter CLK_HZ = 27_000_000,       // klokfrequentie van het bord
  parameter BAUD   = 115_200
) (
  input        clk,
  input        btn_rst_n,              // resetknop (0 = ingedrukt)
  output [5:0] led_n,
  output       uart_tx,
  input        uart_rx
);
  localparam DIV  = CLK_HZ / BAUD;     // klokcycli per UART-bit
  localparam TDIV = CLK_HZ / 1000;     // klokcycli per timertik (1 ms)

  // Reset: laat de knop los synchroon met de klok los (twee flipflops), zoals in week 6.
  reg [1:0] rst_sync = 2'b00;
  always @(posedge clk or negedge btn_rst_n)
    if (!btn_rst_n) rst_sync <= 2'b00;
    else            rst_sync <= {rst_sync[0], 1'b1};
  wire rst_n = rst_sync[1];

  wire [7:0] gpio_out;
  cpu_f #("hello.hex", 1, DIV, TDIV, "hello.dat", 1) cpu(
    .clk(clk), .rst_n(rst_n), .halted(),
    .pc_out(), .r0(), .r1(), .r2(), .r3(), .r4(), .r5(), .r6(), .r7(),
    .flag_z(), .flag_n(), .flag_c(), .flag_v(),
    .txd(uart_tx), .rxd(uart_rx), .gpio_in(8'h00), .gpio_out(gpio_out)
  );

  assign led_n = ~gpio_out[5:0];
endmodule
```

## 4. Verificatie van W8F

### Dezelfde programma's, naast elkaar

W8I (asynchroon RAM) en W8F draaien dezelfde zes programma's tegelijk. Registers, vlaggen en het hele RAM moeten identiek zijn, en W8F mag precies één cyclus per uitgevoerde `LD` langer doen. Die laatste eis is scherp: klopt het aantal cycli niet exact, dan gebeurt er iets wat je niet begrijpt.

```verilog
// FILE: cpu_fpga/tb_f_compare.v
// Dezelfde programma's op W8I (asynchroon RAM) en W8F (blok-RAM, LD in 3 cycli):
// het resultaat moet identiek zijn, en W8F mag precies één cyclus per uitgevoerde LD langer doen.
module pair_f #(parameter P = "", parameter D = "none", parameter DL = 0) (
  input clk, input rst_n,
  output done,
  output reg [31:0] cyc_i, cyc_f, loads,
  output reg same
);
  wire hi, hf;
  wire [7:0] ipc, i0, i1, i2, i3, i4, i5, i6, i7, fpc, f0, f1, f2, f3, f4, f5, f6, f7;
  wire iz, in_, ic, iv, fz, fn, fc, fv;
  cpu_i #(P, 1, 16, 1, D, DL) a(.clk(clk), .rst_n(rst_n), .halted(hi), .pc_out(ipc), .r0(i0), .r1(i1), .r2(i2), .r3(i3),
      .r4(i4), .r5(i5), .r6(i6), .r7(i7), .flag_z(iz), .flag_n(in_), .flag_c(ic), .flag_v(iv), .rxd(1'b1), .gpio_in(8'd0));
  cpu_f #(P, 1, 16, 1, D, DL) b(.clk(clk), .rst_n(rst_n), .halted(hf), .pc_out(fpc), .r0(f0), .r1(f1), .r2(f2), .r3(f3),
      .r4(f4), .r5(f5), .r6(f6), .r7(f7), .flag_z(fz), .flag_n(fn), .flag_c(fc), .flag_v(fv), .rxd(1'b1), .gpio_in(8'd0));
  assign done = hi & hf;
  initial begin cyc_i = 0; cyc_f = 0; loads = 0; end
  always @(posedge clk) if (rst_n) begin
    if (!hi) cyc_i <= cyc_i + 1;
    if (!hf) begin cyc_f <= cyc_f + 1; if (b.mem_rd) loads <= loads + 1; end
  end
  integer k;
  always @* begin
    same = ({i0, i1, i2, i3, i4, i5, i6, i7} === {f0, f1, f2, f3, f4, f5, f6, f7}) && ({iz, in_, ic, iv} === {fz, fn, fc, fv});
    for (k = 0; k < 240; k = k + 1) if (a.io.ram.mem[k] !== b.io.ram.mem[k]) same = 0;
  end
endmodule

module tb_f_compare;
  reg clk = 0, rst_n = 0;
  wire [5:0] d, s;
  wire [31:0] ci0, cf0, l0, ci1, cf1, l1, ci2, cf2, l2, ci3, cf3, l3, ci4, cf4, l4, ci5, cf5, l5;
  integer fouten = 0;
  pair_f #("sum.hex")                  p0(clk, rst_n, d[0], ci0, cf0, l0, s[0]);
  pair_f #("mul.hex")                  p1(clk, rst_n, d[1], ci1, cf1, l1, s[1]);
  pair_f #("sort.hex", "sort.dat", 1)  p2(clk, rst_n, d[2], ci2, cf2, l2, s[2]);
  pair_f #("primes.hex")               p3(clk, rst_n, d[3], ci3, cf3, l3, s[3]);
  pair_f #("gcd.hex")                  p4(clk, rst_n, d[4], ci4, cf4, l4, s[4]);
  pair_f #("calls.hex")                p5(clk, rst_n, d[5], ci5, cf5, l5, s[5]);
  always #5 clk = ~clk;

  task rapport(input [127:0] naam, input [31:0] ci, input [31:0] cf, input [31:0] l, input gelijk);
    begin
      $display("%0s  W8I: %5d cycli   W8F: %5d cycli   (%0d LD's)   resultaat %0s", naam, ci, cf, l, gelijk ? "identiek" : "VERSCHILT");
      if (!gelijk) fouten = fouten + 1;
      if (cf !== ci + l) begin fouten = fouten + 1; $display("  FAIL: verwacht %0d cycli", ci + l); end
    end
  endtask

  initial begin
    #22 rst_n = 1;
    wait (&d);
    #20;
    rapport("som       ", ci0, cf0, l0, s[0]);
    rapport("mul 16bit ", ci1, cf1, l1, s[1]);
    rapport("sorteren  ", ci2, cf2, l2, s[2]);
    rapport("priem     ", ci3, cf3, l3, s[3]);
    rapport("ggd       ", ci4, cf4, l4, s[4]);
    rapport("subroutine", ci5, cf5, l5, s[5]);
    if (fouten == 0) $display("PASS: W8F geeft overal hetzelfde resultaat als W8I en kost precies één extra cyclus per LD");
    $finish;
  end
endmodule
```

De meting:

| Programma | W8I (cycli) | W8F (cycli) | Aantal LD's |
|-----------|------------:|------------:|------------:|
| som | 66 | 66 | 0 |
| mul | 190 | 190 | 0 |
| sorteren | 564 | 620 | 56 |
| priem | 3 596 | 3 694 | 98 |
| ggd | 60 | 60 | 0 |
| subroutine | 114 | 114 | 0 |

### De interrupt- en apparatentests

De tests uit week 22 en 23 draaien ook op W8F. Het enige verschil is de naam van de CPU. Maak er kopieën van met zoeken-en-vervangen (bijvoorbeeld met `sed`):

<!-- COPYSED cpu_irq/tb_irq.v cpu_fpga/tb_irq_f.v "module tb_irq;"=>"module tb_irq_f;" "cpu_i #("=>"cpu_f #(" -->
<!-- COPYSED cpu_irq/tb_blink.v cpu_fpga/tb_blink_f.v "module tb_blink;"=>"module tb_blink_f;" "cpu_i #("=>"cpu_f #(" -->
<!-- COPYSED cpu_irq/tb_fpga_top.v cpu_fpga/tb_fpga_top_f.v "module tb_fpga_top;"=>"module tb_fpga_top_f;" "fpga_top #(CLK_HZ, BAUD) dut("=>"fpga_top_f #(CLK_HZ, BAUD) dut(" -->

```text
sed 's/module tb_irq;/module tb_irq_f;/; s/cpu_i #(/cpu_f #(/' tb_irq.v > tb_irq_f.v
sed 's/module tb_blink;/module tb_blink_f;/; s/cpu_i #(/cpu_f #(/' tb_blink.v > tb_blink_f.v
sed 's/module tb_fpga_top;/module tb_fpga_top_f;/; s/fpga_top #(CLK_HZ, BAUD) dut(/fpga_top_f #(CLK_HZ, BAUD) dut(/' tb_fpga_top.v > tb_fpga_top_f.v
```

Dat het hergebruik zo goed werkt, is een teken van een goed ontworpen testbench: de test hangt af van het gedrag van de CPU en niet van zijn interne cyclustelling. Alle drie slagen.

## 5. De resultaten

Gemeten met Yosys 0.69 en nextpnr (via YoWASP), `seed 1`, met 27 MHz als doel:

| | W8I | W8F |
|--|----:|----:|
| LUT4 | 3 202 | 700 |
| Flipflops | 2 148 | 265 |
| Blok-RAM | 0 | 1 |
| Logische elementen op HX8K | 5 297 (68 %) | 898 (11 %) |
| Maximale frequentie HX8K | 34,3 MHz | 48,0 MHz |
| Kritiek pad: logica / routering | 6,1 / 22,0 ns | 5,5 / 14,7 ns |
| Past op UP5K (5 280 LC's) | nee | ja, maximaal 18,4 MHz |

W8F is 6 keer kleiner en de klokfrequentie is 40 % hoger. Ook de routering nam sterk af: minder LUT's betekent korter bedraad.

Veel UP5K-borden (bijvoorbeeld de iCEBreaker en de UPduino) draaien op 12 MHz. Daar haalt W8F ruim de maximale 18,4 MHz. Op 27 MHz zou hij het niet halen.

### Winst in tijd, niet in cycli

Alleen cycli vergelijken is misleidend. De uitvoeringstijd is:

```text
 tijd = cycli / frequentie
```

| Programma | W8I: tijd bij 34,3 MHz | W8F: tijd bij 48,0 MHz | Versnelling |
|-----------|-----------------------:|-----------------------:|:-----------:|
| sorteren | 564 / 34,3 = 16,4 µs | 620 / 48,0 = 12,9 µs | 1,27 × |
| priem | 3 596 / 34,3 = 104,8 µs | 3 694 / 48,0 = 77,0 µs | 1,36 × |
| som | 66 / 34,3 = 1,92 µs | 66 / 48,0 = 1,38 µs | 1,40 × |

Er zijn meer cycli (de extra stap voor `LD`) en toch is het sneller, omdat de klok zoveel sneller kan. Dat is de les van elke architectuurvergelijking.

## 6. Bewijzen dat de synthese klopt: gate-level simulatie

In week 23 ging het mis: de simulatie slaagde, maar de hardware was leeg. Een gate-level simulatie voorkomt zulke verrassingen. Je simuleert dan niet je Verilog, maar de netlijst die Yosys maakte, opgebouwd uit de echte celtypen van de FPGA (LUT's, flipflops, carry-ketens en blok-RAM). Slaagt je testbench daar ook op, dan weet je dat de synthese het gedrag intact liet.

Voor een snelle simulatie gebruiken we dezelfde kleine klok als in de testbench van week 23:

```verilog
// FILE: cpu_fpga/fpga_top_small.v
// Dezelfde FPGA-top, maar met een kleine "klok" zodat de gate-level simulatie van de netlijst snel is.
module fpga_top_small(
  input        clk,
  input        btn_rst_n,
  output [5:0] led_n,
  output       uart_tx,
  input        uart_rx
);
  fpga_top_f #(16000, 1000) t(.clk(clk), .btn_rst_n(btn_rst_n), .led_n(led_n), .uart_tx(uart_tx), .uart_rx(uart_rx));
endmodule
```

<!-- COPYSED cpu_fpga/tb_fpga_top_f.v cpu_fpga/tb_gate.v "module tb_fpga_top_f;"=>"module tb_gate;" "fpga_top_f #(CLK_HZ, BAUD) dut("=>"fpga_top_small dut(" -->

De testbench voor de netlijst is `tb_fpga_top_f.v` met twee vervangingen: `module tb_gate;` en `fpga_top_small dut(`.

```bash
# FILE: cpu_fpga/gatesim.sh
#!/bin/bash
# Gate-level simulatie: de testbench draait op de door Yosys gesynthetiseerde netlijst (LUT's, flipflops, blok-RAM)
# in plaats van op je Verilog. Zo bewijs je dat de synthese het ontwerp niet veranderd heeft.
# Gebruik: bash gatesim.sh        (na fpga_flow.sh; gebruikt dezelfde VENV)
set -e
VENV=${VENV:-$HOME/fpga-venv}
YOSYS="$VENV/bin/yowasp-yosys"
CELLS=$(ls "$VENV"/lib/python*/site-packages/yowasp_yosys/share/ice40/cells_sim.v)
SOURCES="alu.v idecode.v memories.v memories_f.v datapath_i.v control_f.v mmio_f.v cpu_f.v fpga_top_f.v fpga_top_small.v"
python3 asm.py hello.asm
cp -n hello.hex prog.hex 2>/dev/null || true
cp -n hello.dat data.hex 2>/dev/null || true
"$YOSYS" -q -p "read_verilog -sv $SOURCES; synth_ice40 -flatten -top fpga_top_small; write_verilog -noattr netlist_small.v"
iverilog -g2012 -o gate.vvp tb_gate.v netlist_small.v "$CELLS"
vvp gate.vvp | grep -v finish
```

```text
bash gatesim.sh
```

De uitvoer:

```text
bericht: 7 tekens, LED wisselde 7 keer
PASS (gate-level): de gesynthetiseerde netlijst zegt 'W8 OK' via de UART en laat de LED knipperen
```

Dit draait op de netlijst van ongeveer 800 kB Verilog met `SB_LUT4`, `SB_DFF*`, `SB_CARRY` en een `SB_RAM40_4K`. Het is de strengste verificatie die je zonder echt bord kunt doen.

## 7. Hoe optimaliseer je verder?

| Techniek | Idee | Effect |
|----------|------|--------|
| Blok-RAM gebruiken | synchrone uitlezing (zoals hierboven) | veel minder LUT's en flipflops |
| Pipelinen | het kritieke pad met registers in stukken knippen (week 20) | hogere klok, maar meer flipflops en hazards |
| Retiming | de tool schuift registers door de logica | hogere klok zonder je code te veranderen (mits ondersteund) |
| Fanout verminderen | een signaal met honderden bestemmingen vertraagt, dus dupliceer het register | minder routering |
| One-hot toestandscodering | meer flipflops, maar veel eenvoudiger logica | snellere FSM's |
| Resource sharing | één opteller voor meerdere taken gebruiken (zoals de ALU voor adressen) | kleiner |
| Clock enable in plaats van gated clock | `if (en)` in plaats van de klok te poorten | veilig en door de FPGA ondersteund |
| Een andere seed of strengere constraint | nextpnr heeft willekeur, en een hogere doelfrequentie geeft hardere optimalisatie | soms +10 % |

### De afweging

```text
 oppervlakte (LUT's)  ◄──►  snelheid (MHz)  ◄──►  energie
```

Je kunt zelden alles tegelijk verbeteren. Snel betekent vaak groter (duplicaten, pipelineregisters) en klein betekent vaak langzamer (hergebruik). Op een chip kost oppervlakte geld, op een FPGA kost het vooral ruimte.

### Een woord over energie

Het vermogen van CMOS (week 2) is ruwweg:

```text
 P_dynamisch  ≈  α · C · V² · f
```

Hierin is α de fractie poorten die per klokperiode schakelt, C de capaciteit die wordt omgeladen, V de voedingsspanning en f de frequentie. Halve spanning geeft vier keer minder vermogen en halve frequentie de helft. Daarom draaien telefoonchips op lage spanningen en schakelen ze delen uit die niet nodig zijn. Een FPGA gebruikt ook veel energie in het statische deel (lekstroom) en in de routering.

## 8. Lab

1. Draai `bash fpga_flow.sh hx8k` (W8I) en daarna `bash fpga_flow.sh hx8k fpga_top_f` (W8F). Vul de tabel uit paragraaf 5 met je eigen cijfers (die kunnen licht afwijken door de versie van de tools).
2. Draai `bash gatesim.sh` en bevestig PASS. Maak daarna iets stuk in `control_f.v` (haal bijvoorbeeld de derde stap van `LD` weg) en kijk of zowel de RTL-test als de gate-level test falen.
3. Zoek in `pnr.log` het kritieke pad van W8F en vergelijk het met dat van W8I. Door welke onderdelen loopt het?
4. Verander de `--seed` in `fpga_flow.sh` (1, 2, 3, 4, 5) en noteer per seed de maximale frequentie. Hoeveel verschilt het?
5. Draai het script voor `up5k` met `FREQ=12` en met `FREQ=27`. Wat zegt het rapport?

## 9. Oefeningen

1. Het datageheugen van W8I heeft 240 bytes. Hoeveel flipflops kost dat? Waarom kost het daarnaast nog tientallen LUT's per bit?
2. Een programma voert 10 000 instructies uit, waarvan 20 % `LD`, op W8I (34 MHz, 2 cycli per instructie) en op W8F (48 MHz, 3 cycli voor `LD`). Bereken de tijd op beide en de versnelling.
3. Een kritiek pad bestaat uit 0,5 ns clock-to-Q, 12 LUT's van 0,4 ns en 12 routeringen van 1,2 ns. Wat is de maximale frequentie? Wat levert het halveren van het aantal LUT's (en routeringen) op het pad op?
4. Leg uit waarom een asynchroon geheugen niet op blok-RAM past.
5. Wat is het verschil tussen een RTL-simulatie en een gate-level simulatie, en wat bewijst de tweede extra?
6. Je ontwerp haalt 27 MHz niet en het kritieke pad loopt door de ALU. Noem drie dingen die je kunt proberen.
7. Waarom kost het programmageheugen (de instructie-ROM) iets aan LUT's? (Gemeten: een programma van 37 instructies kost 700 LUT's, een van 20 instructies 660.) Schat de kosten per instructie.
8. Uitdaging: maak ook het instructiegeheugen synchroon (blok-RAM). Wat moet je veranderen aan het ophalen van instructies? Hoeveel cycli kost een instructie dan? Hint: het adres moet een periode eerder bekend zijn.

## 10. Antwoorden

1. 240 × 8 = 1 920 flipflops. Daarnaast heeft elke uitgangsbit een multiplexer van 240 naar 1 (grofweg 150 LUT's per bit), plus een decodering van het adres voor het schrijven. Samen geeft dat de gemeten ongeveer 2 500 LUT's bovenop de flipflops.
2. Instructies: 20 % LD = 2 000, de overige 8 000. W8I: 10 000 × 2 = 20 000 cycli / 34,3 MHz = 583 µs. W8F: 8 000 × 2 + 2 000 × 3 = 22 000 cycli / 48 MHz = 458 µs. De versnelling is 583 / 458 ≈ 1,27.
3. Het totaal is 0,5 + 12 × 0,4 + 12 × 1,2 = 0,5 + 4,8 + 14,4 = 19,7 ns, dus ongeveer 50,8 MHz. Met 6 LUT's en 6 routeringen: 0,5 + 2,4 + 7,2 = 10,1 ns, ongeveer 99 MHz, bijna het dubbele.
4. Het blok-RAM legt het adres vast bij een klokflank en levert de data via een register aan de uitgang. Asynchroon lezen verlangt dat de data zonder klok verschijnt. De hardware kan dat niet, dus bouwt de tool het uit flipflops en multiplexers.
5. RTL-simulatie voert jouw Verilog uit, gate-level simulatie voert de netlijst uit die de tool gegenereerd heeft. De tweede bewijst dat de synthese (met alle optimalisaties en interpretaties van `initial`-blokken, geheugens en klokken) het gedrag niet veranderd heeft.
6. Bijvoorbeeld: de ALU pipelinen (een register in het midden), minder fanout (registers dupliceren), een snellere opteller (carry-ketens gebruiken in plaats van losse logica), het pad verkorten door gedeeltelijke resultaten vooraf te berekenen, een hogere doelfrequentie opgeven of een andere seed proberen.
7. Een ROM in LUT's: elke plek bevat constanten die de synthese waar mogelijk wegwerkt, maar elke andere instructie voegt logica toe. Uit de twee metingen volgt (700 − 660) / (37 − 20) ≈ 2,4 LUT's per instructie. Bij een volle ROM van 256 niet-triviale instructies zou dat 600 tot 700 LUT's zijn. Een blok-RAM voor instructies zou dat overnemen.
8. Het instructiegeheugen zou bij het adres in T0 pas na een klokperiode data geven. Je hebt dan een extra ophaalstap nodig, of je legt de PC een cyclus vooruit (prefetch) zodat het adres er eerder is. Een instructie kost dan 3 cycli (ophalen in twee stappen en uitvoeren). Dit is precies de aanleiding voor pipelining.

## 11. Zelftest

1. Waar staan de 1920 flipflops voor in W8I?
2. Wat is slack?
3. Waarom domineert routering het kritieke pad op een FPGA?
4. Wat bewijst een gate-level simulatie?
5. Waarom is het vergelijken van cycli niet genoeg om twee CPU's te vergelijken?

Antwoorden: (1) Voor 240 bytes datageheugen (240 × 8) als losse flipflops. (2) Het verschil tussen de beschikbare tijd (de klokperiode) en de padvertraging. (3) De programmeerbare draden en schakelaars zijn veel langzamer dan de LUT's zelf. (4) Dat de gesynthetiseerde netlijst hetzelfde gedrag heeft als je ontwerp. (5) Tijd is cycli gedeeld door frequentie, en een CPU met meer cycli kan toch sneller zijn als zijn klok sneller is.

## 12. Verder lezen

- Het hoofdstuk over timinganalyse in elk boek over digitaal ontwerp, bijvoorbeeld Harris en Harris, 3.5 (timing van sequentiële logica).
- De documentatie van nextpnr over constraints en seeds, en de documentatie over blok-RAM van jouw FPGA-familie (de "Memory Usage Guide").
- Een inleiding over statische timinganalyse (STA) uit de ASIC-wereld. De concepten zijn hetzelfde, het gereedschap is duurder.

Volgende week: de FPGA is een tussenstap. Nu bouwen we de bijzondere machine uit week 19, de TTA, echt uit chips op een printplaat.
