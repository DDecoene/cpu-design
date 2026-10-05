---
title: "Week 12 · Getalrepresentatie, shifters en vermenigvuldigen"
---

<p class="subtitle">Fase 3 · Verilog en de ALU · ongeveer 12 uur</p>

# Week 12: Getalrepresentatie, shifters en vermenigvuldigen

## Wat je na deze week kunt

- getallen met en zonder teken lezen en schrijven in binair en hexadecimaal
- tekenuitbreiding (sign extension) toepassen en uitleggen waarom het werkt
- vaste-kommagetallen (Q-formaat) gebruiken
- een barrel shifter ontwerpen en uitleggen waarom hij zo is opgebouwd
- een sequentiële vermenigvuldiger met een FSM bouwen en testen
- uitleggen hoe CPU's omgaan met delen, drijvende komma en endianness

## 1. Getallen zonder teken

Een getal van n bits zonder teken heeft de waarde Σ bitᵢ · 2ⁱ en ligt tussen 0 en 2ⁿ − 1.

| Bits | Bereik zonder teken | Hex-cijfers |
|------|---------------------|-------------|
| 4 | 0 ... 15 | 1 |
| 8 | 0 ... 255 | 2 |
| 16 | 0 ... 65 535 | 4 |
| 32 | 0 ... 4 294 967 295 | 8 |

Hexadecimaal (basis 16) gebruikt de cijfers 0 tot 9 en A tot F. Eén hex-cijfer is precies vier bits. Ontwerpers schrijven bits daarom als hex: `1010_1111` is `0xAF`. Leer deze tabel uit je hoofd:

```text
0=0000  1=0001  2=0010  3=0011  4=0100  5=0101  6=0110  7=0111
8=1000  9=1001  A=1010  B=1011  C=1100  D=1101  E=1110  F=1111
```

## 2. Getallen met teken

Er zijn drie historische manieren om een negatief getal in bits te zetten:

| Methode | Idee | Probleem |
|---------|------|----------|
| Tekenbit en grootte (sign-magnitude) | bit 7 is het teken, de rest de grootte | twee nullen (+0 en −0), optellen is ingewikkeld |
| Eén-complement | negatief = alle bits omkeren | twee nullen en een extra carry-correctie ("end-around carry") |
| Twee-complement | negatief = alle bits omkeren, plus 1 | geen, het werkt gewoon |

Het twee-complement wint. Dezelfde opteller werkt ongewijzigd voor getallen met en zonder teken, en er is maar één nul. Alle moderne processors gebruiken het.

Het bereik voor n bits is −2ⁿ⁻¹ tot 2ⁿ⁻¹ − 1:

| Bits | Bereik met teken |
|------|------------------|
| 8 | −128 ... 127 |
| 16 | −32 768 ... 32 767 |
| 32 | −2 147 483 648 ... 2 147 483 647 |

Waarom werkt het twee-complement? In n bits geldt x + (−x) = 2ⁿ, en dat verschijnt in n bits als 0 omdat de carry wegvalt. Het twee-complement van x is dus precies 2ⁿ − x. Een bitpatroon `b` waarvan het hoogste bit gezet is, lees je als `b − 2ⁿ`.

Een voorbeeld: `0xD6` is 214 zonder teken. Met teken is het 214 − 256 = −42.

### Tekenuitbreiding

Wil je een 8-bit getal met teken in een 16-bit register zetten zonder dat de waarde verandert, dan moet je het tekenbit herhalen:

```text
 +5  = 0000_0101  →  0000_0000_0000_0101   (nullen aanvullen)
 −5  = 1111_1011  →  1111_1111_1111_1011   (enen aanvullen)
```

In Verilog schrijf je `{{8{x[7]}}, x}`. Zonder teken vul je gewoon nullen aan. Het verwisselen van die twee is een klassieke bron van bugs.

### Overflow en saturatie

Overflow (V) ken je uit week 11. Sommige processors, vooral voor audio en beeld, rekenen saturerend: wordt het resultaat te groot, dan blijft het op het maximum staan in plaats van rond te lopen. Een lichte tint die naar 255 gaat en bij 256 ineens zwart wordt, is onbruikbaar. Saturatie is extra logica bovenop de opteller.

## 3. Vaste komma (fixed point)

Een CPU zonder drijvende-kommaeenheid kan toch kommagetallen gebruiken. Je spreekt af dat een aantal bits achter de komma staat. Q4.4 betekent 4 bits voor en 4 bits achter de komma. De opgeslagen waarde is het gewone getal maal 2⁴ = 16.

| Getal | Opgeslagen (Q4.4) |
|-------|-------------------|
| 1,5 | 1,5 × 16 = 24 = `0x18` |
| 2,25 | 2,25 × 16 = 36 = `0x24` |
| 5,75 | 5,75 × 16 = 92 = `0x5C` |

Optellen gaat met de gewone opteller. Bij vermenigvuldigen heeft het resultaat twee keer zoveel kommabits: `0x18 × 0x24 = 24 × 36 = 864`. Dat is Q8.8, dus 864 / 256 = 3,375. Om terug te gaan naar Q4.4 schuif je 4 plaatsen naar rechts: 864 >> 4 = 54 = `0x36`, en 54 / 16 = 3,375. Dat klopt.

Vaste komma is snel en eenvoudig en wordt veel in embedded systemen gebruikt. Het nadeel is dat je zelf de schaal moet bijhouden en dat het bereik beperkt is.

### Drijvende komma in het kort

Een floating point-getal heeft drie delen: teken, exponent en mantisse, zoals wetenschappelijke notatie. Een IEEE 754 `float` van 32 bits heeft 1 tekenbit, 8 exponentbits en 23 mantissabits. Het bereik is enorm (ongeveer 10⁻³⁸ tot 10³⁸), maar de hardware voor optellen en vermenigvuldigen is veel ingewikkelder dan voor gehele getallen. Wij bouwen dit niet. Je moet wel weten dat veel kleine CPU's het niet hebben en het in software doen.

## 4. Endianness

Een 16-bit getal `0x1234` past niet in één byte-geheugenplaats. Welke byte komt eerst?

| | Adres 0 | Adres 1 |
|--|---------|---------|
| Big-endian | `0x12` (hoogste byte) | `0x34` |
| Little-endian | `0x34` (laagste byte) | `0x12` |

Intel, ARM (meestal) en RISC-V zijn little-endian, netwerkprotocollen zijn big-endian. Beide werken, maar je moet een keuze maken en die consequent volhouden. Voor onze 8-bit CPU speelt dit pas als we 16-bit getallen gaan opslaan.

## 5. Shifters

Een shift verplaatst alle bits. Er zijn vier varianten:

| Naam | Afkorting | Wat komt er binnen | Wiskunde |
|------|-----------|--------------------|----------|
| Logisch links | LSL | nullen rechts | ×2 |
| Logisch rechts | LSR | nullen links | ÷2 (zonder teken) |
| Aritmetisch rechts | ASR | een kopie van het tekenbit links | ÷2 (met teken, naar beneden afgerond) |
| Rotatie rechts | ROR | wat rechts eruit valt komt links binnen | bits blijven behouden |

Een voorbeeld: −3 is `1111_1101`. LSR geeft `0111_1110` = 126, wat voor een getal met teken fout is. ASR geeft `1111_1110` = −2. Dat klopt: −3 / 2 = −1,5, naar beneden afgerond −2.

### De barrel shifter

Hoe schuif je 0 tot 7 plaatsen in één klokcyclus? Niet met zeven keer één plek, maar met trappen (stages). Trap 0 schuift 0 of 1 plek, trap 1 schuift 0 of 2 plekken en trap 2 schuift 0 of 4 plekken. Elke trap is een rij 2:1 multiplexers. Het shiftgetal in binair bepaalt welke trappen actief zijn:

```text
 shift = 5 = 101  →  trap 0 (1 plek) AAN, trap 1 (2 plekken) uit, trap 2 (4 plekken) AAN:  1 + 4 = 5
```

Voor W bits heb je log₂(W) trappen van W multiplexers. Bij 32 bits zijn dat 5 × 32 = 160 multiplexers en een vertraging van 5 mux-niveaus. Elke shift duurt dus even lang, wat je ook kiest.

```verilog
// FILE: week12/shifter.v
// Barrel shifter. mode: 00 LSL, 01 LSR, 10 ASR, 11 ROR.
module shifter #(parameter W = 8, parameter SW = 3) (
  input  [W-1:0]  a,
  input  [SW-1:0] sh,
  input  [1:0]    mode,
  output [W-1:0]  y
);
  wire [W-1:0] st [0:SW];          // st[k] is het tussenresultaat voor trap k
  assign st[0] = a;

  genvar k;
  generate
    for (k = 0; k < SW; k = k + 1) begin : stage
      localparam N = 1 << k;       // deze trap schuift N plaatsen
      wire [W-1:0] x   = st[k];
      wire [W-1:0] lsl = x << N;
      wire [W-1:0] lsr = x >> N;
      wire [W-1:0] asr = $signed(x) >>> N;
      wire [W-1:0] ror = (x >> N) | (x << (W - N));
      wire [W-1:0] r   = (mode == 2'b00) ? lsl :
                         (mode == 2'b01) ? lsr :
                         (mode == 2'b10) ? asr : ror;
      assign st[k+1] = sh[k] ? r : x;
    end
  endgenerate

  assign y = st[SW];
endmodule
```

Een ASR over meerdere trappen werkt: elke trap kopieert het tekenbit opnieuw. Een rotatie over meerdere trappen werkt ook.

```verilog
// FILE: week12/sext.v
// Tekenuitbreiding van 8 naar 16 bits.
module sext8to16(input [7:0] x, output [15:0] y);
  assign y = {{8{x[7]}}, x};
endmodule
```

```verilog
// FILE: week12/tb_shifter.v
module tb_shifter;
  reg  [7:0] a;
  reg  [2:0] sh;
  reg  [1:0] mode;
  wire [7:0] y;
  wire [15:0] ext;
  integer ia, is, im, fouten = 0, sa;
  reg [7:0] ey;

  shifter #(8, 3) dut(a, sh, mode, y);
  sext8to16 se(a, ext);

  initial begin
    for (im = 0; im < 4; im = im + 1)
      for (ia = 0; ia < 256; ia = ia + 1)
        for (is = 0; is < 8; is = is + 1) begin
          a = ia; sh = is; mode = im; #1;
          sa = $signed(a);
          case (im)
            0: ey = ia << is;
            1: ey = ia >> is;
            2: ey = sa >>> is;
            3: ey = (ia >> is) | (ia << (8 - is));
          endcase
          if (y !== ey) begin
            fouten = fouten + 1;
            if (fouten < 10) $display("FAIL mode=%0d a=%h sh=%0d: y=%h verwacht %h", im, a, is, y, ey);
          end
        end

    // Tekenuitbreiding: de waarde (met teken) blijft gelijk.
    for (ia = 0; ia < 256; ia = ia + 1) begin
      a = ia; #1;
      if ($signed(ext) !== $signed(a)) begin fouten = fouten + 1; $display("FAIL sext %h", a); end
    end

    if (fouten == 0) $display("PASS: barrel shifter (LSL, LSR, ASR, ROR) en tekenuitbreiding kloppen exhaustief");
    $finish;
  end
endmodule
```

## 6. Vermenigvuldigen

### Op papier

Binair vermenigvuldigen is makkelijker dan decimaal, want elk cijfer is 0 of 1. Je schrijft het getal op, of een rij nullen.

```text
        1 0 1   (5)
      × 0 1 1   (3)
      -------
        1 0 1   ← × bit 0 (=1): schrijf 101
      1 0 1     ← × bit 1 (=1): schrijf 101, één plaats opgeschoven
    0 0 0       ← × bit 2 (=0): schrijf 000
    -----------
      0 1 1 1 1  (15)
```

Het is dus een reeks van verschuiven en optellen: voor elk bit van de vermenigvuldiger tel je het (opgeschoven) vermenigvuldigtal op als dat bit 1 is. Een vermenigvuldiging van n bij n bits geeft een resultaat van 2n bits.

### Drie manieren om het te bouwen

| Aanpak | Ruimte | Tijd | Opmerking |
|--------|--------|------|-----------|
| Sequentieel (shift-and-add) | klein: 1 opteller | n cycli | wat wij bouwen |
| Array / parallel | groot: n² optellers | 1 cyclus (maar langzaam) | moderne CPU's, in geoptimaliseerde vorm |
| Booth (radix-4) | middel | halveert het aantal optellingen | meerdere bits per stap, ook geschikt voor getallen met teken |

### De sequentiële vermenigvuldiger

Zo werkt de rekenmachine in cijfers: een register voor het opgeschoven vermenigvuldigtal (breed, 16 bits), een register voor de vermenigvuldiger (8 bits, wordt naar rechts geschoven) en een accumulator (16 bits). Elke klokperiode gebeurt dit:

1. Is het laagste bit van de vermenigvuldiger 1, dan tel je het opgeschoven vermenigvuldigtal bij de accumulator op.
2. Je schuift het vermenigvuldigtal één plaats naar links en de vermenigvuldiger één plaats naar rechts.
3. Na 8 stappen is de accumulator het product.

Het gedrag is een mini-FSM met twee toestanden (rust en bezig), plus een teller. In Verilog ziet dat er zo uit:

```verilog
// FILE: week12/mul8.v
// 8x8 -> 16 bits, zonder teken, 8 cycli.
module mul8(
  input             clk,
  input             rst_n,
  input             start,
  input      [7:0]  a,
  input      [7:0]  b,
  output reg [15:0] p,
  output reg        done
);
  reg [15:0] mcand;     // vermenigvuldigtal, schuift naar links
  reg [7:0]  mplier;    // vermenigvuldiger, schuift naar rechts
  reg [3:0]  cnt;
  reg        busy;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      p <= 0; done <= 0; busy <= 0; mcand <= 0; mplier <= 0; cnt <= 0;
    end else if (!busy) begin
      if (start) begin
        mcand <= {8'b0, a};  mplier <= b;  p <= 0;  cnt <= 0;
        busy <= 1;  done <= 0;
      end
    end else begin
      if (mplier[0]) p <= p + mcand;
      mcand  <= mcand << 1;
      mplier <= mplier >> 1;
      cnt    <= cnt + 1'b1;
      if (cnt == 4'd7) begin busy <= 0; done <= 1; end
    end
endmodule
```

```verilog
// FILE: week12/tb_mul8.v
module tb_mul8;
  reg clk = 0, rst_n = 0, start = 0;
  reg  [7:0] a = 0, b = 0;
  wire [15:0] p;
  wire done;
  integer ia, ib, fouten = 0, cycli = 0;

  mul8 dut(clk, rst_n, start, a, b, p, done);
  always #5 clk = ~clk;

  initial begin
    #12 rst_n = 1;
    for (ia = 0; ia < 256; ia = ia + 5)         // elke vijfde waarde van a, alle waarden van b
      for (ib = 0; ib < 256; ib = ib + 1) begin
        @(negedge clk); a = ia; b = ib; start = 1;
        @(negedge clk); start = 0; cycli = 0;
        while (!done) begin @(negedge clk); cycli = cycli + 1; end
        if (p !== ia * ib) begin
          fouten = fouten + 1;
          if (fouten < 10) $display("FAIL: %0d * %0d = %0d i.p.v. %0d", ia, ib, p, ia * ib);
        end
        if (cycli != 8) begin fouten = fouten + 1; $display("FAIL: duur %0d cycli", cycli); end
      end
    // Hoeken
    @(negedge clk); a = 255; b = 255; start = 1;
    @(negedge clk); start = 0;
    while (!done) @(negedge clk);
    if (p !== 16'd65025) begin fouten = fouten + 1; $display("FAIL 255*255 = %0d", p); end
    if (fouten == 0) $display("PASS: sequentiele vermenigvuldiger klopt (13000+ producten) in vaste tijd");
    $finish;
  end
endmodule
```

### Delen

Delen is trager dan vermenigvuldigen. Het eenvoudigste algoritme (restoring division) is een lange deling in binair: schuif de rest een plaats op, probeer de deler eraf te trekken en kijk of dat lukte. Voor n bits kost dat n cycli. Veel kleine CPU's hebben geen deler en doen het in software. De 8086 had zowel een vermenigvuldiger als een deler in hardware. De 6502 en de Z80 hadden geen van beide.

## 7. Draai de labs

```text
cd labs/week12
iverilog -g2012 -o a.vvp tb_shifter.v shifter.v sext.v && vvp a.vvp
iverilog -g2012 -o b.vvp tb_mul8.v mul8.v && vvp b.vvp
```

Experimenten:

1. Laat de vermenigvuldiger tellen hoeveel optellingen hij doet. Hoeveel optellingen doet `mul8` gemiddeld per product? Het antwoord is gemiddeld 4 bij 8 willekeurige bits.
2. Pas de shifter aan zodat ASR niet het tekenbit kopieert maar nullen invoert. Welke test vindt dat?
3. Bekijk in een golfvorm van `mul8` wat er elke cyclus gebeurt bij 5 × 3.

## 8. Oefeningen

1. Wat zijn de bereiken van 12 bits zonder teken en met teken?
2. Schrijf −42 als 8-bit twee-complement, in binair en in hex.
3. Breid `0xB5` en `0x35` uit van 8 naar 16 bits, (a) als getal met teken en (b) zonder teken.
4. Tel `0x6A + 0x3C` op in 8 bits. Wat zijn de vlaggen N, C en V, en wat betekent dat?
5. Zet 5,75 en 0,5 om naar Q4.4 en vermenigvuldig ze. Wat is het resultaat in Q4.4?
6. Een 32-bit barrel shifter: hoeveel 2:1 multiplexers heeft hij en hoeveel mux-niveaus diep is hij? Vergelijk dat met een shifter die 31 keer één plaats schuift in 31 klokcycli.
7. Volg `mul8` voor 5 × 3 stap voor stap: wat staat er na elke cyclus in `p`, `mcand` en `mplier`?
8. Uitdaging: bouw een `div8`-module (restoring division) die `a / b` en `a % b` berekent in 8 cycli, met een test tegen `/` en `%`. Wat doe je bij `b = 0`?

## 9. Antwoorden

1. Zonder teken 0 ... 4095, met teken −2048 ... 2047.
2. 42 is `0010_1010`. Omkeren geeft `1101_0101` en plus 1 geeft `1101_0110`, dus 0xD6.
3. 0xB5 = `1011_0101` heeft het hoogste bit gezet. (a) Met teken: 0xFFB5 (waarde −75). (b) Zonder teken: 0x00B5 (waarde 181). 0x35 is positief, dus in beide gevallen 0x0035.
4. 0x6A = 106 en 0x3C = 60, de som is 166 = 0xA6. Als getal met teken is 0xA6 gelijk aan −90, dus er is overflow: V = 1, N = 1, C = 0. Twee positieve getallen gaven een negatief resultaat.
5. 5,75 is `0x5C` (92) en 0,5 is `0x08` (8). Het product is 92 × 8 = 736. Dat is Q8.8. Schuif 4 naar rechts: 736 >> 4 = 46 = `0x2E`, en 46 / 16 = 2,875. Dat klopt.
6. 5 trappen × 32 = 160 multiplexers, 5 mux-niveaus diep. De seriële shifter heeft één shiftregister, maar doet er tot 31 cycli over.
7. Start: p=0, mcand=5, mplier=3 (`11`). Stap 1: bit=1, dus p=5, mcand=10, mplier=1. Stap 2: bit=1, dus p=15, mcand=20, mplier=0. Stap 3 tot en met 8: bit=0, p blijft 15, mcand verdubbelt en mplier blijft 0. Na stap 8 is p = 15 en done = 1.
8. Houd een rest (8+1 bit) en een quotiënt bij. Per stap schuif je de rest naar links met het volgende bit van `a` erin en trek je `b` ervan af. Is het resultaat niet negatief, dan wordt dat de nieuwe rest en schrijf je een 1 in het quotiënt, anders niet. Bij `b = 0` geef je een foutvlag (delen door nul), anders krijg je een zinloos resultaat.

## 10. Zelftest

1. Waarom wint het twee-complement van tekenbit en grootte?
2. Wat doet tekenuitbreiding en hoe schrijf je het in Verilog?
3. Wat is het verschil tussen LSR en ASR?
4. Hoe werkt een barrel shifter?
5. Hoeveel cycli kost een sequentiële 8×8-vermenigvuldiger?

Antwoorden: (1) Er is maar één nul en dezelfde opteller werkt voor beide soorten getallen. (2) Het tekenbit wordt herhaald in de nieuwe hogere bits: `{{8{x[7]}}, x}`. (3) LSR vult links nullen aan en ASR kopieert het tekenbit. (4) Met trappen van 1, 2, 4 ... plaatsen, aan of uit gezet door de bits van het shiftgetal. (5) 8 cycli voor het rekenen, plus één voor de start.

## 11. Verder lezen

- Harris en Harris, 5.2 en 5.3 (rekenkunde en getalsystemen).
- David Goldberg, "What every computer scientist should know about floating-point arithmetic" (online te vinden).
- De geschiedenis van de Pentium FDIV-bug, een fout in een deeltabel.

---

> **Fase 3 is af.** Je schrijft nu Verilog, test op een professionele manier en hebt een volledige ALU, shifter en vermenigvuldiger gebouwd. Dat zijn alle rekenonderdelen van een CPU. Vanaf volgende week bouwen we de rest: de instructieset, het datapath en de besturing. Dan wordt het een computer.

Volgende week: het ontwerp van de instructieset (ISA), het contract tussen hardware en software.
