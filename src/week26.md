---
title: "Week 26 · Eindopdracht en de weg naar echt silicium"
---

<p class="subtitle">Fase 6 · Van code naar chip · ongeveer 16 uur</p>

# Week 26: Eindopdracht en de weg naar silicium

## Wat je na deze week kunt

- de stappen van een ASIC-ontwerpstroom benoemen en uitleggen wat er anders is dan bij een FPGA
- je T8 omzetten naar een compacte chipvariant en zijn grootte schatten
- begrijpen waarom een vast programma in ROM de hardware kan laten krimpen
- een eindopdracht kiezen, uitvoeren en beoordelen
- terugkijken op zes maanden en bepalen wat je vervolgens leert

> **Wat in deze week getest is.** De chipvariant, de verificatie en de grootteschattingen in dit hoofdstuk zijn gedraaid in simulatie en met Yosys. Een echte ASIC-ontwerpstroom met een procesbibliotheek en een bestelling bij Tiny Tapeout is niet uitgevoerd. Voor die laatste stap (prijzen, deadlines en regels) volg je de actuele documentatie van het project.

## 1. Van FPGA naar echte chip

Een ASIC (application-specific integrated circuit) is een chip waarvan de transistoren voor jouw ontwerp zijn gemaakt. De stroom lijkt op die van een FPGA, maar eindigt anders:

| Stap | Wat gebeurt er |
|------|----------------|
| RTL (Verilog) | jouw ontwerp, zoals in de hele cursus |
| Synthese | omzetten naar standaardcellen: kleine, vooraf getekende poorten en flipflops van de fabrikant |
| Floorplan en plaatsing | cellen op de chip leggen |
| Klokboom | de klok met gelijke vertraging naar alle flipflops verdelen |
| Routering | de metaallagen die alles verbinden |
| Verificatie | DRC (houdt het ontwerp zich aan de fabricageregels?), LVS (komt de getekende chip overeen met het schema?) en timing |
| GDSII | het bestand met de maskertekeningen |
| Fabricage | de fabriek maakt de chips |

Voor alle stappen bestaat open-source gereedschap: Yosys (synthese), OpenROAD (plaatsen en routeren) en Magic en KLayout (tekeningen en controles), samengebracht in de ontwerpstroom OpenLane. De procesbibliotheek (PDK) is open, bijvoorbeeld SkyWater SKY130 (130 nm) en GF180MCU.

### Tiny Tapeout

Tiny Tapeout is een project waarin honderden kleine ontwerpen op één gedeelde chip worden gemaakt. Een eigen chip kost dan enkele tientallen tot een paar honderd euro in plaats van tienduizenden. Een ontwerp is een Verilog-module met een vaste poortindeling (8 ingangen, 8 uitgangen, 8 bidirectionele pennen, klok en reset) die in een tegel van vaste grootte moet passen. Controleer op de website van het project de actuele regels, de grootte van een tegel, de kosten en de deadlines. Die veranderen per ronde.

Het verschil met een FPGA is groot: een fout in silicium is niet te repareren. Daarom is de verificatie uit week 10, 16, 19 en 25 geen luxe.

## 2. De T8 als chip

Een tegel is klein (in de orde van duizend standaardcellen; controleer de actuele waarde). Onze T8 uit week 19 heeft 256 bytes RAM en 256 instructies. Dat past niet. We maken daarom een compacte variant:

- De programmateller wordt 6 bits (64 instructies).
- Het datageheugen wordt 8 bytes (3 adresbits).
- Het programma zit als logica in de chip (een `case`-tabel), want een chip heeft geen `$readmemh`.

### Eerst bewijzen dat de herstructurering klopt

We splitsen het gedragsmodel in een kern met instelbare breedtes (`t8_core`) en een los ROM. Met de volle breedtes (8 en 8) moet de kern exact de machine uit week 19 zijn. Dat controleren we met dezelfde willekeurige test, cyclus voor cyclus.

<!-- COPY tta/tta.v tt_t8/tta.v -->
<!-- COPY tta/tta_asm.py tt_t8/tta_asm.py -->

Kopieer `tta.v` en `tta_asm.py` uit `labs/tta/` naar `labs/tt_t8/`.

```verilog
// FILE: tt_t8/t8_core.v
// De kern van de T8, met instelbare breedte van de programmateller (PCW) en van het geheugenadres (AW).
// Het programmageheugen zit er niet in: de instructie komt van buiten (rom_addr -> instr).
// Met PCW = 8 en AW = 8 is dit exact de machine uit week 19; kleinere waarden maken hem geschikt voor een kleine chip.
module t8_core #(parameter PCW = 8, parameter AW = 8) (
  input                clk,
  input                rst_n,
  input  [7:0]         in_port,
  output reg [7:0]     out_port,
  output reg           halted,
  output [PCW-1:0]     rom_addr,
  input  [23:0]        instr,
  output [7:0]         r0, r1, r2, r3, op_out, res_out,
  output               flag_z, flag_n, flag_c
);
  localparam D_NOP = 0, D_R0 = 1, D_R1 = 2, D_R2 = 3, D_R3 = 4, D_OP = 5, D_ADD = 6, D_SUB = 7,
             D_AND = 8, D_OR = 9, D_XOR = 10, D_PC = 11, D_MAR = 12, D_MEM = 13, D_OUT = 14, D_SHL = 15,
             D_ADC = 16, D_HALT = 31;
  localparam S_IMM = 0, S_R0 = 1, S_R1 = 2, S_R2 = 3, S_R3 = 4, S_RES = 5, S_RESHR = 6, S_RESNOT = 7,
             S_MEM = 8, S_IN = 9, S_PC2 = 10, S_FLAGS = 11;

  reg [PCW-1:0] pc;
  reg [7:0]     op, res;
  reg [AW-1:0]  mar;
  reg [7:0]     r [0:3];
  reg [7:0]     ram [0:(1<<AW)-1];
  reg           zf, nf, cf;
  integer i;

  assign rom_addr = pc;
  wire [2:0] guard = instr[23:21];
  wire [4:0] dst   = instr[20:16];
  wire [4:0] src   = instr[12:8];
  wire [7:0] imm   = instr[7:0];

  wire [7:0] res_shr = {1'b0, res[7:1]};
  wire [7:0] pc2     = {{(8-PCW){1'b0}}, pc} + 8'd2;
  reg  [7:0] bus;
  always_comb begin
    case (src)
      S_IMM:    bus = imm;
      S_R0:     bus = r[0];
      S_R1:     bus = r[1];
      S_R2:     bus = r[2];
      S_R3:     bus = r[3];
      S_RES:    bus = res;
      S_RESHR:  bus = res_shr;
      S_RESNOT: bus = ~res;
      S_MEM:    bus = ram[mar];
      S_IN:     bus = in_port;
      S_PC2:    bus = pc2;
      S_FLAGS:  bus = {5'b00000, nf, cf, zf};
      default:  bus = 8'h00;
    endcase
  end

  reg go;
  always_comb begin
    case (guard)
      3'd0: go = 1'b1;
      3'd1: go = zf;
      3'd2: go = ~zf;
      3'd3: go = cf;
      3'd4: go = ~cf;
      3'd5: go = nf;
      3'd6: go = ~nf;
      default: go = 1'b0;
    endcase
  end

  reg [8:0] sum;
  reg [7:0] lg;
  always_comb begin
    sum = 9'd0; lg = 8'h00;
    case (dst)
      D_ADD: sum = {1'b0, op} + {1'b0, bus};
      D_SUB: sum = {1'b0, op} + {1'b0, ~bus} + 9'd1;
      D_ADC: sum = {1'b0, op} + {1'b0, bus} + {8'b0, cf};
      D_SHL: sum = {bus, 1'b0};
      D_AND: lg = op & bus;
      D_OR:  lg = op | bus;
      D_XOR: lg = op ^ bus;
      default: ;
    endcase
  end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pc <= 0; op <= 0; res <= 0; mar <= 0; zf <= 0; nf <= 0; cf <= 0; halted <= 0; out_port <= 0;
      for (i = 0; i < 4; i = i + 1) r[i] <= 8'h00;
    end else if (!halted) begin
      pc <= pc + 1'b1;
      if (go) begin
        case (dst)
          D_R0: r[0] <= bus;
          D_R1: r[1] <= bus;
          D_R2: r[2] <= bus;
          D_R3: r[3] <= bus;
          D_OP: op <= bus;
          D_ADD, D_SUB, D_ADC, D_SHL: begin res <= sum[7:0]; cf <= sum[8]; zf <= (sum[7:0] == 8'h00); nf <= sum[7]; end
          D_AND, D_OR, D_XOR:         begin res <= lg; cf <= 1'b0; zf <= (lg == 8'h00); nf <= lg[7]; end
          D_PC:   pc <= bus[PCW-1:0];
          D_MAR:  mar <= bus[AW-1:0];
          D_MEM:  ram[mar] <= bus;
          D_OUT:  out_port <= bus;
          D_HALT: halted <= 1'b1;
          default: ;
        endcase
      end
    end

  assign r0 = r[0]; assign r1 = r[1]; assign r2 = r[2]; assign r3 = r[3];
  assign op_out = op; assign res_out = res;
  assign flag_z = zf; assign flag_n = nf; assign flag_c = cf;
endmodule
```

```verilog
// FILE: tt_t8/tb_core_equiv.v
// De parametriseerbare kern (met PCW = 8, AW = 8) moet exact de machine uit week 19 zijn.
// 300 willekeurige programma's, na elke klokcyclus vergeleken met tta.v.
module tb_core_equiv;
  reg clk = 0, rst_n = 0;
  reg [7:0] inp = 0;
  wire [7:0] ob, pcb, r0b, r1b, r2b, r3b, resb;
  wire hb, zb, nb, cb;
  wire [7:0] oc, r0c, r1c, r2c, r3c, opc, resc, rom_addr;
  wire hc, zc, nc, cc;
  reg  [23:0] rom [0:255];
  wire [23:0] instr = rom[rom_addr];
  integer fouten = 0, prog, k, idx, kind, kk, cycli, bad = 0;
  reg [4:0] dsel;
  reg [2:0] gsel;
  reg [7:0] ssel;

  tta #("none", 0, "none", 0) b(.clk(clk), .rst_n(rst_n), .in_port(inp), .out_port(ob), .halted(hb), .pc_out(pcb),
      .r0(r0b), .r1(r1b), .r2(r2b), .r3(r3b), .res_out(resb), .flag_z(zb), .flag_n(nb), .flag_c(cb));
  t8_core #(8, 8) c(.clk(clk), .rst_n(rst_n), .in_port(inp), .out_port(oc), .halted(hc), .rom_addr(rom_addr), .instr(instr),
      .r0(r0c), .r1(r1c), .r2(r2c), .r3(r3c), .op_out(opc), .res_out(resc), .flag_z(zc), .flag_n(nc), .flag_c(cc));
  always #5 clk = ~clk;

  function [23:0] mv(input [2:0] g, input [4:0] d, input [7:0] s, input [7:0] imm);
    mv = {g, d, s, imm};
  endfunction

  task make_program(input integer lengte);
    begin
      for (idx = 0; idx < 256; idx = idx + 1) rom[idx] = mv(0, 31, 0, 0);
      for (idx = 0; idx < lengte; idx = idx + 1) begin
        kind = {$random} % 100;
        gsel = ({$random} % 100 < 40) ? 3'd0 : ({$random} % 8);
        if (kind < 6) begin
          kk = {$random} % 4;
          rom[idx] = mv(gsel, 11, 0, (idx + 1 + kk > lengte) ? lengte : idx + 1 + kk);
        end else begin
          case ({$random} % 15)
            0: dsel = 0;   1: dsel = 1;   2: dsel = 2;   3: dsel = 3;   4: dsel = 4;   5: dsel = 5;
            6: dsel = 6;   7: dsel = 7;   8: dsel = 8;   9: dsel = 9;   10: dsel = 10;
            11: dsel = 12; 12: dsel = 13; 13: dsel = 14; default: dsel = ({$random} % 2) ? 15 : 16;
          endcase
          ssel = {$random} % 12;
          rom[idx] = mv(gsel, dsel, ssel, $random);
        end
      end
      rom[lengte] = mv(0, 31, 0, 0);
    end
  endtask

  always @(posedge clk) begin
    #1;
    if (rst_n) begin
      if ({pcb, r0b, r1b, r2b, r3b, resb, ob, hb} !== {rom_addr, r0c, r1c, r2c, r3c, resc, oc, hc} ||
          b.op !== opc || {zb, nb, cb} !== {zc, nc, cc} || b.mar !== c.mar) begin
        bad = bad + 1;
        if (bad < 4) $display("FAIL: verschil bij pc=%0d", pcb);
      end
    end
  end

  initial begin
    #22;
    for (prog = 0; prog < 300; prog = prog + 1) begin
      make_program(30 + ({$random} % 150));
      inp = $random;
      for (k = 0; k < 256; k = k + 1) begin b.rom[k] = rom[k]; b.ram[k] = {$random}; c.ram[k] = b.ram[k]; end
      rst_n = 0; repeat (2) @(posedge clk); #1;
      rst_n = 1; cycli = 0;
      while (!(hb && hc) && cycli < 400) begin @(posedge clk); cycli = cycli + 1; end
      if (!(hb && hc)) begin fouten = fouten + 1; $display("FAIL prog %0d: niet gestopt", prog); end
      for (k = 0; k < 256; k = k + 1) if (b.ram[k] !== c.ram[k]) begin fouten = fouten + 1; if (fouten < 5) $display("FAIL prog %0d: ram[%0d]", prog, k); end
      #20;
    end
    if (bad !== 0) fouten = fouten + 1;
    if (fouten == 0) $display("PASS: t8_core (PCW=8, AW=8) is cyclus voor cyclus gelijk aan de machine uit week 19, in 300 willekeurige programma's");
    $finish;
  end
endmodule
```

### Het programma en het ROM

Het programma in de chip is de rij van Fibonacci, op de uitgangspennen.

```text
; FILE: tt_t8/chip.tta
; Het programma in de chip: de rij van Fibonacci (modulo 256) op de uitgangspennen, een getal per zes klokcycli.
        #0 -> R0            ; a
        #1 -> R1            ; b
lus:    R0 -> OUT           ; toon a
        R0 -> OP
        R1 -> ADD           ; a + b
        R1 -> R0            ; a = b
        RES -> R1           ; b = a + b
        JMP lus
```

Het ROM maken we met een generator, zodat het programma de enige bron van waarheid blijft:

```python
# FILE: tt_t8/mkrom.py
"""Maakt van een T8-programma (.hex van tta_asm.py) een synthetiseerbaar ROM-module in Verilog.
Gebruik:  python3 mkrom.py programma.hex 6 > rom_t8.v      (6 = aantal adresbits van de programmateller)
Een echte chip heeft geen $readmemh nodig: het programma wordt een 'case'-tabel, dat is gewone logica."""
import sys

HALT = 0x1F0000


def maak_rom(woorden, pcw):
    n = 1 << pcw
    gebruikt = [(a, w) for a, w in enumerate(woorden) if w != HALT]
    if gebruikt and max(a for a, _ in gebruikt) >= n:
        raise SystemExit(f"het programma gebruikt adres {max(a for a, _ in gebruikt)}, maar {pcw} adresbits halen maar {n - 1}")
    regels = [
        "// Gegenereerd door mkrom.py. Niet met de hand aanpassen.",
        f"module t8_rom (input [{pcw - 1}:0] a, output reg [23:0] d);",
        "  always_comb begin",
        "    case (a)",
    ]
    for a, w in gebruikt:
        regels.append(f"      {pcw}'d{a}: d = 24'h{w:06X};")
    regels += ["      default: d = 24'h1F0000;   // HALT", "    endcase", "  end", "endmodule"]
    return "\n".join(regels) + "\n"


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        raise SystemExit(2)
    woorden = [int(x, 16) for x in open(sys.argv[1]).read().split()]
    sys.stdout.write(maak_rom(woorden, int(sys.argv[2])))
```

```python
# FILE: tt_t8/test_mkrom.py
# Het gegenereerde ROM moet precies de woorden van het programma bevatten; en het mag niet groter zijn dan het adresbereik.
import re, subprocess, sys
from mkrom import maak_rom
from tta_asm import assemble

prog = assemble(open("chip.tta").read())[0]
tekst = maak_rom(prog, 6)
gevonden = {int(a): int(w, 16) for a, w in re.findall(r"6'd(\d+): d = 24'h([0-9A-F]{6});", tekst)}
verwacht = {a: w for a, w in enumerate(prog) if w != 0x1F0000}
assert gevonden == verwacht, (gevonden, verwacht)
assert "default: d = 24'h1F0000" in tekst
try:
    maak_rom([0x010000] * 100, 6)      # 100 woorden passen niet in 6 adresbits
    raise AssertionError("moest falen")
except SystemExit as e:
    assert "adres" in str(e)
print("PASS: mkrom maakt een ROM met precies de programmawoorden en weigert programma's die te groot zijn")
```

Het resultaat voor ons programma (gegenereerd, nooit met de hand aanpassen):

```verilog
// FILE: tt_t8/rom_t8.v
// Gegenereerd door mkrom.py. Niet met de hand aanpassen.
module t8_rom (input [7:0] a, output reg [23:0] d);
  always_comb begin
    case (a)
      8'd0: d = 24'h010000;
      8'd1: d = 24'h020001;
      8'd2: d = 24'h0E0100;
      8'd3: d = 24'h050100;
      8'd4: d = 24'h060200;
      8'd5: d = 24'h010200;
      8'd6: d = 24'h020500;
      8'd7: d = 24'h0B0002;
      default: d = 24'h1F0000;   // HALT
    endcase
  end
endmodule
```

### Het toplevel voor de chip

```verilog
// FILE: tt_t8/tt_t8.v
// Het toplevel voor Tiny Tapeout: de T8 als kleine chip. De poortnamen volgen de afspraak van het project.
//   ui_in  = de ingangspoort (IN)        uo_out  = de uitgangspoort (OUT)
//   uio_out = debug: {halted, 0, programmateller}
module tt_um_t8_tta (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);
  wire [5:0]  pc_addr;
  wire [23:0] instr;
  wire        halted;

  t8_rom rom (.a(pc_addr), .d(instr));
  t8_core #(.PCW(6), .AW(3)) core (
    .clk(clk), .rst_n(rst_n), .in_port(ui_in), .out_port(uo_out), .halted(halted),
    .rom_addr(pc_addr), .instr(instr),
    .r0(), .r1(), .r2(), .r3(), .op_out(), .res_out(), .flag_z(), .flag_n(), .flag_c()
  );

  assign uio_out = {halted, 1'b0, pc_addr};
  assign uio_oe  = 8'hFF;                       // alle bidirectionele pennen zijn uitgangen
  wire _unused = &{ena, uio_in, 1'b0};
endmodule
```

### De test van de chip

```verilog
// FILE: tt_t8/tb_tt_t8.v
// De chip: het Fibonacci-programma draait en de uitgangspennen tonen de rij.
module tb_tt_t8;
  reg clk = 0, rst_n = 0;
  wire [7:0] uo, uio_out, uio_oe;
  integer fouten = 0, n = 0, i;
  reg [7:0] a, b, t, verwacht;

  tt_um_t8_tta dut(.ui_in(8'h00), .uo_out(uo), .uio_in(8'h00), .uio_out(uio_out), .uio_oe(uio_oe), .ena(1'b1), .clk(clk), .rst_n(rst_n));
  always #5 clk = ~clk;

  initial begin
    // Referentie: dezelfde rij, berekend in de testbench (modulo 256).
    a = 0; b = 1;
    #22 rst_n = 1;
    // De chip voert in elke ronde van 6 cycli één OUT uit (op programmaadres 2). In de cyclus daarna,
    // met de programmateller op 3, staat de nieuwe waarde op de uitgangspennen.
    repeat (500) begin
      @(posedge clk); #1;
      if (uio_out[5:0] === 6'd3) begin
        if (uo !== a) begin fouten = fouten + 1; if (fouten < 5) $display("FAIL: uitvoer %0d, verwacht %0d (nr %0d)", uo, a, n); end
        t = a + b; a = b; b = t; n = n + 1;
      end
    end
    if (n < 70) begin fouten = fouten + 1; $display("FAIL: slechts %0d waarden gezien", n); end
    if (uio_oe !== 8'hFF) begin fouten = fouten + 1; $display("FAIL: uio_oe"); end
    if (uio_out[7] !== 1'b0) begin fouten = fouten + 1; $display("FAIL: de chip is gestopt"); end
    if (fouten == 0) $display("PASS: de chip toont de rij van Fibonacci modulo 256 (%0d waarden gecontroleerd)", n);
    $finish;
  end
endmodule
```

## 3. Hoe groot is hij?

Zonder een echte procesbibliotheek kunnen we de oppervlakte niet berekenen, maar Yosys kan het ontwerp wel omzetten in eenvoudige poorten en flipflops. Dat geeft een bruikbare schatting.

### Het verrassende resultaat: een vast programma laat hardware verdwijnen

De volledige chip (kern en ROM) is gesynthetiseerd voor verschillende RAM-groottes, en steeds kwam er ongeveer 185 cellen uit, ook bij 256 bytes RAM. Dat kan niet kloppen voor een machine met 256 bytes RAM. De verklaring is dat ons programma het RAM nooit gebruikt. De synthesetool ziet dat en gooit het RAM weg, evenals alle bronnen en bestemmingen die het programma niet gebruikt. Wat overblijft is een machine die alleen kan wat dit ene programma nodig heeft.

Dat is een belangrijke les over chips: een vast programma in ROM is geen software meer maar logica, en logica die nooit nodig is, verdwijnt. Je moet die 185 cellen dus niet lezen als "de grootte van de T8".

### De programmeerbare kern

Om te weten hoe groot de machine is die elk programma kan draaien, synthetiseren we de kern los, met de instructie als ingang:

```python
# FILE: tt_t8/core_size.py
"""Schat de grootte van de programmeerbare T8-kern (zonder programma): de instructie is een ingang van de chip,
dus de synthese kan niets wegwerken op grond van een vast programma. Hetzelfde idee als chip_size.sh, andere vraag."""
import os, subprocess, sys

VENV = os.environ.get("VENV", os.path.expanduser("~/fpga-venv"))
YOSYS = f"{VENV}/bin/yowasp-yosys"


def schat(pcw, aw):
    top = f"""module kern(input clk, input rst_n, input [7:0] in_port, output [7:0] out_port, output halted,
                 output [{pcw-1}:0] rom_addr, input [23:0] instr);
  t8_core #({pcw}, {aw}) c(clk, rst_n, in_port, out_port, halted, rom_addr, instr, , , , , , , , , );
endmodule
"""
    open("kern_tmp.v", "w").write(top)
    script = ("read_verilog -sv t8_core.v kern_tmp.v; synth -top kern -flatten; "
              "abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX; opt_clean; tee -o kern_stat.txt stat")
    subprocess.run([YOSYS, "-q", "-p", script], capture_output=True, text=True)
    cellen = ff = 0
    for regel in open("kern_stat.txt"):
        d = regel.split()
        if len(d) >= 2 and d[1] == "cells":
            cellen = int(d[0])
        if len(d) == 2 and d[1].startswith("$_DFF"):
            ff += int(d[0])
    return cellen, ff


if __name__ == "__main__":
    print(f"{'PCW':>4} {'AW':>3} {'RAM (bytes)':>12} {'cellen':>7} {'flipflops':>10}")
    for pcw, aw in [(6, 0), (6, 2), (6, 3), (6, 4), (6, 5), (8, 8)]:
        c, f = schat(pcw, aw)
        print(f"{pcw:4d} {aw:3d} {(1 << aw):12d} {c:7d} {f:10d}")
```

De uitkomst:

| Programmateller | RAM | Cellen | Flipflops |
|----------------:|----:|-------:|----------:|
| 6 bits | 1 byte | 593 | 73 |
| 6 bits | 4 bytes | 680 | 99 |
| 6 bits | 8 bytes | 792 | 132 |
| 6 bits | 16 bytes | 1 015 | 197 |
| 6 bits | 32 bytes | 1 428 | 326 |
| 8 bits | 256 bytes | 7 309 | 2 123 |

Zo lees je dit: de kern zonder geheugen is ongeveer 500 tot 600 cellen. Elk extra bit RAM kost een flipflop plus uitleeslogica. Het RAM van 256 bytes is verantwoordelijk voor ruim 85 % van de volledige machine. Een chip met een programma in ROM komt dus in de orde van 800 tot 1000 cellen (de ROM-logica erbij), aan de rand van wat in één kleine tegel past. Reken het zelf na met de actuele tegelgrootte.

```bash
# FILE: tt_t8/chip_size.sh
#!/bin/bash
# Schat de grootte van de chip: Yosys zet het ontwerp om in eenvoudige poorten en flipflops, zoals voor een echte chip.
# Er is hier geen echte celbibliotheek (SKY130) bij, dus dit is een SCHATTING in 'poorten', niet de uiteindelijke oppervlakte.
# Gebruik:  bash chip_size.sh [PCW] [AW]      (standaard 6 en 3)       VENV=map met de Yosys-installatie
VENV=${VENV:-$HOME/fpga-venv}
PCW=${1:-6}
AW=${2:-3}
YOSYS="$VENV/bin/yowasp-yosys"
python3 tta_asm.py chip.tta
python3 mkrom.py chip.hex $PCW > rom_t8.v
sed "s/#(.PCW(6), .AW(3))/#(.PCW($PCW), .AW($AW))/; s/wire \[5:0\]  pc_addr;/wire [$((PCW-1)):0]  pc_addr;/; s/assign uio_out = {halted, 1'b0, pc_addr};/assign uio_out = {halted, {$((7-PCW)){1'b0}}, pc_addr};/" tt_t8.v > tt_t8_cfg.v
"$YOSYS" -q -p "read_verilog -sv tt_t8_cfg.v t8_core.v rom_t8.v; synth -top tt_um_t8_tta -flatten; abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX; opt_clean; tee -o chip_stat.txt stat" > /dev/null
grep -E "cells|\\\$_" chip_stat.txt | sed 's/^ *//'
```

### Wat je hiermee leert

- Op een chip is elk bit geheugen duur. Daarom hebben chips weinig RAM en veel slimme logica.
- Het ontwerp bepaalt de grootte. Ons T8-ontwerp heeft een prima verhouding, omdat de besturing wegvalt.
- Een gegenereerd ROM (uit een te assembleren programma) is hoe vaste programma's in echte chips komen: firmware is logica.

## 4. De eindopdracht

De opdracht: maak iets dat je in deze cursus niet gebouwd hebt, test het zoals een professional en schrijf het op. Kies een van de onderstaande opdrachten, of verzin iets van dezelfde omvang (ongeveer 40 uur).

| # | Opdracht | Wat je laat zien |
|---|----------|------------------|
| 1 | T8 met twee bussen: twee moves per cyclus, met een assembler die conflicten weigert en een verificatie tegen het bestaande model | architectuur, parallellisme, verificatie |
| 2 | W8 met cache: de data-cache uit week 21 aan de CPU koppelen, met een meting van de versnelling | geheugenhiërarchie |
| 3 | De 74HC-print afmaken: schema in KiCad, controle tegen `t8_board.v`, bestelling en bouw | hardware realiseren |
| 4 | Een Forth-systeem voor S8: een interactieve interpreter met UART, woordenboek en compile-modus | software op eigen hardware |
| 5 | W8 op een FPGA met VGA of LED-matrix: een klein spel of animatie (de bouwstenen staan in week 27 tot 30) | systeemontwerp |
| 6 | De T8-chip in Tiny Tapeout: het hele ontwerp, de testbenches en de documentatie klaarmaken voor inzending | silicium |
| 7 | Bit-serial CPU: een CPU die 1 bit tegelijk rekent, met minimale hardware | een nieuwe architectuur |
| 8 | Een eigen ISA (met assembler, simulator en CPU) voor een toepassing naar keuze | volledig ontwerp |

### Wat je oplevert

1. Een specificatie: wat doet het en wat doet het niet (één pagina).
2. Het ontwerp: blokschema, belangrijkste keuzes en waarom.
3. De code: alle bronbestanden, goed gedocumenteerd.
4. Verificatie: minstens een zelfcontrolerende testbench, een referentiemodel en een willekeurige test. Voeg een mutatietest toe: maak met opzet drie bugs en laat zien dat je tests ze vinden.
5. Een meting: prestaties, grootte of timing, met cijfers.
6. Een verslag van vier tot zes pagina's: wat werkte, wat ging mis en wat heb je geleerd.

### Beoordeling (voor jezelf)

| Onderdeel | Punten |
|-----------|:------:|
| Het werkt en je bewijst het met tests | 30 |
| Kwaliteit van de verificatie (referentiemodel, willekeur, mutaties) | 25 |
| Ontwerpkeuzes zijn beargumenteerd en gemeten | 20 |
| Code en documentatie zijn leesbaar | 15 |
| Verslag, eerlijk over fouten en beperkingen | 10 |

Eerlijkheid over wat misging is geen minpunt. Het is wat professionals het meest waarderen.

## 5. Het eindexamen

Beantwoord de vragen zonder terug te kijken (de antwoorden staan eronder). Een goed resultaat is 20 van 25.

Elektronica en logica:

1. Wat is de wet van Ohm? Bereken de weerstand voor een LED van 2 V bij 5 V en 10 mA.
2. Hoe vormen twee transistoren een CMOS-inverter en waarom gebruikt hij in rust geen stroom?
3. Waarom is NAND universeel?
4. Vereenvoudig `Y = AB + AB'` en `Y = A + A'B`.
5. Beschrijf een SR-latch en leg uit waarom een flipflop die op de klokflank werkt beter is dan een latch.

Digitaal ontwerp:

6. Wat is het verschil tussen combinatorische en sequentiële logica? Geef van elk een voorbeeld.
7. Wat is het kritieke pad en hoe bepaalt het de klokfrequentie?
8. Schrijf in Verilog een 8-bit teller met reset, enable en load. Welke toekenning gebruik je en waarom?
9. Wat is een tri-state bus en wat is een busconflict?
10. Hoe trek je af met een opteller en wat betekent C = 1 na een SUB in deze cursus?

Architectuur:

11. Noem de onderdelen van een datapath en vertel wat de besturing doet. Wat is microcode?
12. Wat is het verschil tussen een register-, een stack- en een transport-triggered machine? Noem van elk een voordeel.
13. Wat kost een genomen sprong in de tweetrapspipeline van W8P en waarom zijn er geen datahazards?
14. Wat zegt `tijd = instructies × CPI / frequentie`? Verklaar ermee waarom W8F sneller is dan W8I, ondanks meer cycli.
15. Wat is forwarding en wat is het load-use-probleem?

Systemen en praktijk:

16. Wat is memory-mapped I/O? Hoe werkt een interrupt en wat bewaart de hardware?
17. Hoe werkt een direct-mapped cache? Splits een adres in tag, index en offset.
18. Wat is een LUT en waarom past een asynchroon RAM niet op blok-RAM?
19. Wat is een gate-level simulatie en wat bewijst ze?
20. Waarom is een vast programma in ROM op een chip logica en wat betekent dat voor de grootte?

Verificatie:

21. Waarom vergelijk je een ontwerp met een referentiemodel en niet met je eigen verwachting?
22. Wat is een mutatietest en welk voorbeeld heb je in deze cursus gezien?
23. Waarom slaagde de eerste versie van de interrupttest ondanks een fout in de hardware?
24. Noem twee ontwerpfouten die de bordsimulatie van de T8 vond voordat er een print was.
25. Wat is het verschil tussen "de simulatie slaagt" en "het ontwerp werkt"?

### Antwoorden

1. V = I × R. R = (5 − 2) / 0,010 = 300 Ω (kies 330 Ω).
2. Een PMOS naar Vdd en een NMOS naar GND, met dezelfde ingang. Ze staan nooit tegelijk aan, dus er is geen pad van plus naar min. Alleen bij het schakelen loopt er stroom.
3. Alle andere poorten zijn uit NAND te bouwen (NOT, AND, OR, XOR).
4. AB + AB' = A(B + B') = A. A + A'B = A + B.
5. Twee kruiselings gekoppelde NOR- of NAND-poorten. Een latch is transparant zolang de enable aan staat, wat bij terugkoppeling tot oscillatie leidt. Een flipflop neemt alleen op de klokflank over.
6. Combinatorisch: de uitgang hangt alleen af van de huidige ingangen (ALU, multiplexer). Sequentieel: er is geheugen (register, teller).
7. Het langzaamste pad tussen twee flipflops: t_clk→Q + t_logica + t_routering + t_setup. De klokperiode moet minstens zo lang zijn.
8. `always @(posedge clk or negedge rst_n) if (!rst_n) q <= 0; else if (load) q <= d; else if (en) q <= q + 1;` met de niet-blokkerende toekenning `<=`, zodat alle flipflops hun oude waarde lezen.
9. Een bus waarop meerdere bronnen kunnen schrijven via uitgangen die losgekoppeld kunnen worden (Z). Een conflict is wanneer twee bronnen tegelijk met verschillende waarden aansturen (kortsluiting, X in simulatie).
10. A − B = A + ~B + 1. C = 1 betekent dat er niet geleend is: A ≥ B zonder teken.
11. Datapath: registers, ALU, multiplexers en geheugens. Besturing: de signalen per klokcyclus, hier een controlegeheugen. Microcode: de besturing als tabel (ROM) in plaats van vaste logica.
12. Register: weinig instructies en veel parallelle mogelijkheden. Stack: korte instructies en een eenvoudige decoder. TTA: geen besturingseenheid en veel parallellisme mogelijk, maar lange programma's.
13. Eén cyclus (de flush). Registers worden aan het eind van EX geschreven en de volgende instructie leest pas in haar eigen EX.
14. W8F heeft meer cycli (LD kost 3) maar een veel hogere klok (48 tegen 34 MHz). Tijd is cycli gedeeld door frequentie, dus is W8F netto sneller (1,27 tot 1,40 ×).
15. Een resultaat rechtstreeks naar een volgende trap sturen zonder te wachten op het registerbestand. Load-use: een instructie die een zojuist geladen waarde meteen gebruikt, moet één cyclus wachten.
16. Apparaatregisters op geheugenadressen. Bij een interrupt worden de PC en de vlaggen bewaard, volgt een sprong naar de vector en herstelt RETI de toestand. De hardware bewaart PC en vlaggen, de software de registers.
17. Een regel is uniek bepaald door de index, en de tag controleert of het juiste blok erin zit. Adres 0xB7 in 16 regels van 4 bytes: tag 10, index 1101, offset 11.
18. Een LUT is een tabel van 16 bit voor een functie van vier ingangen. Blok-RAM legt het adres vast bij een klokflank (synchroon), een asynchroon RAM doet dat niet.
19. Een simulatie van de netlijst die de synthese maakte. Ze bewijst dat de synthese het gedrag niet veranderd heeft.
20. Doordat de invoer constant is, kan de tool hardware wegwerpen die het programma nooit gebruikt: het programma wordt logica. De chip is kleiner dan een universele machine.
21. Het model is een onafhankelijke specificatie en vindt fouten die je zelf niet bedacht. Het kan ook blijken dat je verwachting zelf fout was.
22. Een opzettelijke bug in het ontwerp om te zien dat de test hem vindt. Voorbeelden: het vlaggenherstel bij de interrupt (week 22), het ADC-voorbeeld (week 19) en de voorwaarde LT (week 16).
23. De routine liet de Z-vlag toevallig in een toestand die de hoofdlus niet stoorde. Pas toen de vlaggen met opzet werden verpest, werd de fout zichtbaar.
24. De halt-flipflop die zichzelf wiste, en valse schrijfpulsen tijdens reset.
25. Een simulatie bewijst alleen dat je ontwerp zich gedraagt zoals de tests die je draaide verwachten. Werkt het ontwerp echt, dan geldt dat ook voor de synthese, de timing en de echte hardware.

## 6. Terugblik

Zes maanden geleden wist je misschien niet wat een volt was. Nu heb je:

- een transistor, een poort, een flipflop en een bus begrepen en gebouwd (week 1 tot en met 8)
- Verilog geschreven en professioneel getest (week 9 tot en met 12)
- drie CPU's ontworpen (register, stack en TTA), een assembler en een Forth-compiler geschreven en een pipeline en een cache gebouwd (week 13 tot en met 22)
- een CPU op een FPGA gebracht, geoptimaliseerd en een printplaat- en chipontwerp voorbereid (week 23 tot en met 26)

Dat is veel. Maar wees eerlijk over wat je nog niet hebt:

- Je hebt geen jaren ervaring met grote ontwerpen (miljoenen poorten), complexe protocollen (PCIe, DDR) of cachecoherentie in multicore-systemen.
- Je hebt met simulaties gewerkt, en echte hardware heeft eigen verrassingen (ruis, temperatuur, voeding).
- Je hebt nog geen chip echt laten maken.

Dat zijn de vervolgstappen, en je kent het vak nu goed genoeg om ze te zetten.

## 7. Wat nu?

| Doel | Eerste stap |
|------|-------------|
| Moderne CPU's begrijpen | Hennessy en Patterson, *Computer Architecture: A Quantitative Approach*; ontwerp een RISC-V-CPU (de ISA is open) |
| Echte FPGA-projecten | Bouw een video- of audiosysteem en leer over clock-domain-crossing en timingconstraints |
| Chips maken | Dien een ontwerp in bij Tiny Tapeout en leer OpenLane |
| Verificatie als vak | cocotb, SystemVerilog en UVM, formele verificatie (SymbiYosys) |
| Het hele veld | Volg open-sourceprojecten (RISC-V, OpenROAD, SkyWater) en lees de verslagen van ASIC-ontwerpers |
| Printplaten | Bouw je T8-print en leer daarna sneller ontwerpen met meer lagen en SMD |

### Gemeenschap

Ontwerpen is een sociaal vak. Open-sourcehardware (RISC-V, OpenROAD, Tiny Tapeout, de Lattice- en Gowin-gemeenschappen), forums voor FPGA's en elektronica en conferenties (FOSDEM, het Chaos Communication Congress) zijn prettige plekken om te leren en te delen.

## 8. Slot

Het idee waar deze cursus mee begon: een CPU is niets bijzonders. Het zijn schakelaars die elkaar aan- en uitzetten, gestapeld in lagen die elk een paar dingen doen. Wie de lagen kent, ziet de magie niet meer. Je ziet een slim en begrijpelijk stuk techniek, en je kunt het zelf bouwen.

Veel plezier met je eigen projecten.

---

> **Cursus voltooid.** Je bent zes maanden bezig geweest met CPU-ontwerp, van de wet van Ohm tot een chipontwerp. Bewaar je logboek, je labs en je eindopdracht. Ze zijn je portfolio.

Wil je nog een project? Fase 7 (week 27 tot 30) bouwt een computer die een beeld van een SD-kaart op een VGA-monitor zet, met de CPU uit week 24 en een FPGA. Het begint met week 27.
