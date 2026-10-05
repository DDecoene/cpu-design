---
title: "Week 11 · De ALU ontwerpen"
---

<p class="subtitle">Fase 3 · Verilog en de ALU · ongeveer 12 uur</p>

# Week 11: De ALU

## Wat je na deze week kunt

- uitleggen wat de ALU (arithmetic logic unit) doet en waar hij in de CPU zit
- het twee-complement gebruiken om met een opteller af te trekken
- de vlaggen Z, N, C en V definiëren, berekenen en gebruiken om getallen te vergelijken
- een complete 8-bit ALU in Verilog bouwen en exhaustief testen
- een 4-bit optel/aftrek-schakeling met 74HC-chips bouwen

## 1. Wat doet een ALU?

De ALU is een combinatorische schakeling met twee operanden (`A` en `B`) en een opcode die kiest wat er gebeurt. Je krijgt een resultaat `Y` en een paar vlaggen.

```text
        A ──┐
            ├──►┌─────────┐──► Y (resultaat)
        B ──┘   │   ALU   │──► vlaggen Z N C V
     opcode ───►└─────────┘
```

Hij is combinatorisch: geen klok en geen geheugen (zie week 4). Het onthouden doen de registers eromheen. De ALU is meestal het langzaamste onderdeel van een CPU, omdat de carry door alle bits moet lopen. Zijn vertraging bepaalt vaak de maximale klokfrequentie.

Onze ALU kent acht bewerkingen:

| Opcode | Naam | Bewerking |
|--------|------|-----------|
| 000 | ADD | Y = A + B |
| 001 | SUB | Y = A − B |
| 010 | AND | Y = A & B |
| 011 | OR | Y = A \| B |
| 100 | XOR | Y = A ^ B |
| 101 | NOT | Y = ~A |
| 110 | SHL | Y = A << 1 |
| 111 | SHR | Y = A >> 1 (logisch) |

## 2. Aftrekken met twee-complement

Hoe trek je af zonder aparte aftrekschakeling? Door het negatieve getal erbij op te tellen. Bijna alle computers gebruiken daarvoor het twee-complement:

> Het negatief van een getal vind je door alle bits om te keren en er 1 bij op te tellen.

Een voorbeeld met 4 bits: +3 is `0011`. Omgekeerd is dat `1100`, plus 1 geeft `1101`, dus −3.

| Bits | Waarde (zonder teken) | Waarde (twee-complement) |
|------|:--:|:--:|
| 0000 | 0 | 0 |
| 0001 | 1 | 1 |
| 0111 | 7 | 7 |
| 1000 | 8 | −8 |
| 1001 | 9 | −7 |
| 1111 | 15 | −1 |

Het hoogste bit is het tekenbit. Het mooie is dat optellen hetzelfde werkt voor getallen met en zonder teken. De hardware hoeft er niets van te weten.

Dus A − B = A + (~B) + 1. Je hebt een opteller nodig, een rij inverters (of XOR's) voor B en een carry-in van 1. Met 8 bits: 5 − 3 is `00000101 + 11111100 + 1` = `1 00000010`, dus 2 met een carry-uit van 1. Die carry negeren we in het resultaat.

In week 12 gaan we dieper in op getalrepresentatie. Dit is wat je nu nodig hebt.

## 3. De vlaggen

Naast het resultaat geeft een ALU vier vlaggen (flags): kleine feiten over dat resultaat. De CPU slaat ze op in een vlaggenregister en gebruikt ze voor voorwaardelijke sprongen, zoals "spring als het resultaat nul was" of "spring als A kleiner was dan B".

| Vlag | Naam | Betekenis |
|------|------|-----------|
| Z | Zero | Y is precies 0 |
| N | Negative | het hoogste bit van Y is 1 |
| C | Carry | bij ADD: er was een overdracht uit het hoogste bit. Bij SUB: er was geen borrow (A ≥ B zonder teken) |
| V | oVerflow | het resultaat past niet in twee-complement (het teken klopt niet) |

Een opmerking over C bij aftrekken: we volgen de conventie van ARM en de 6502. Omdat A − B = A + ~B + 1, is de carry-uit 1 als er niet geleend hoeft te worden. C = 1 betekent dus A ≥ B (zonder teken). Andere processors, zoals x86, draaien dit om. Controleer de afspraak altijd als je een nieuwe CPU leest.

### Overflow (V)

Overflow is wanneer twee positieve getallen een negatief resultaat geven (127 + 1 = −128 in 8 bits), of twee negatieve getallen een positief resultaat. De regel:

```text
ADD:  V = 1  als A en B hetzelfde teken hebben, maar Y een ander teken
SUB:  V = 1  als A en B een verschillend teken hebben, en Y heeft een ander teken dan A
```

### Vergelijken met vlaggen

Een vergelijking `A ? B` is een SUB waarvan je het resultaat weggooit en alleen de vlaggen bewaart:

| Vergelijking | Conditie op vlaggen |
|--------------|---------------------|
| A = B | Z = 1 |
| A ≠ B | Z = 0 |
| A ≥ B (zonder teken) | C = 1 |
| A < B (zonder teken) | C = 0 |
| A > B (zonder teken) | C = 1 en Z = 0 |
| A < B (met teken) | N ≠ V |
| A ≥ B (met teken) | N = V |

Met deze vier vlaggen kan een CPU alle vergelijkingen doen. Of de tabel klopt, laten we zo door de simulator controleren.

## 4. De ALU in Verilog

```verilog
// FILE: week11/alu.v
// 8-bit (parametrisch) ALU met vlaggen Z, N, C, V.
module alu #(parameter W = 8) (
  input      [W-1:0] a,
  input      [W-1:0] b,
  input      [2:0]   op,
  output reg [W-1:0] y,
  output             z,
  output             n,
  output reg         c,
  output reg         v
);
  localparam ADD = 3'd0, SUB = 3'd1, AND_ = 3'd2, OR_ = 3'd3,
             XOR_ = 3'd4, NOT_ = 3'd5, SHL = 3'd6, SHR = 3'd7;

  // Eén extra bit breed, zodat de carry uit het hoogste bit zichtbaar is.
  wire [W:0] sum  = {1'b0, a} + {1'b0, b};
  wire [W:0] diff = {1'b0, a} + {1'b0, ~b} + 1'b1;     // A - B = A + ~B + 1

  always @* begin
    y = {W{1'b0}};  c = 1'b0;  v = 1'b0;               // standaardwaarden: geen latches
    case (op)
      ADD:  begin
              y = sum[W-1:0];  c = sum[W];
              v = (a[W-1] == b[W-1]) && (y[W-1] != a[W-1]);
            end
      SUB:  begin
              y = diff[W-1:0]; c = diff[W];
              v = (a[W-1] != b[W-1]) && (y[W-1] != a[W-1]);
            end
      AND_: y = a & b;
      OR_:  y = a | b;
      XOR_: y = a ^ b;
      NOT_: y = ~a;
      SHL:  begin y = {a[W-2:0], 1'b0}; c = a[W-1]; end
      SHR:  begin y = {1'b0, a[W-1:1]}; c = a[0];   end
    endcase
  end

  assign z = (y == {W{1'b0}});
  assign n = y[W-1];
endmodule
```

Kijk naar de opbouw: eerst de standaardwaarden, dan een `case` die de bewerking kiest, en daarna de vlaggen, die alleen uit `y` volgen. Alle acht de bewerkingen worden tegelijk berekend. De `case` is in hardware een multiplexer die kiest welk resultaat doorgelaten wordt.

Dit is eenvoudig, maar bruikbaar. Echte ALU's voegen er rotaties, vergelijkingen en vermenigvuldigers aan toe (week 12).

## 5. Exhaustief testen

Een 8-bit ALU heeft maar 65 536 invoerparen en 8 bewerkingen, dus 524 288 gevallen. Dat doet de simulator in een seconde, dus we testen alles. Het referentiemodel rekent met gewone gehele getallen in de testbench en berekent het resultaat en de vlaggen op een andere manier dan de hardware.

```verilog
// FILE: week11/tb_alu.v
module tb_alu;
  reg  [7:0] a, b;
  reg  [2:0] op;
  wire [7:0] y;
  wire       z, n, c, v;
  integer ia, ib, io, fouten = 0, sa, sb, volledig;
  reg [7:0] ey;
  reg       ec, ev;

  alu #(8) dut(a, b, op, y, z, n, c, v);

  initial begin
    for (io = 0; io < 8; io = io + 1)
      for (ia = 0; ia < 256; ia = ia + 1)
        for (ib = 0; ib < 256; ib = ib + 1) begin
          a = ia; b = ib; op = io; #1;
          sa = $signed(a); sb = $signed(b);             // getallen met teken
          ec = 0; ev = 0; ey = 0;
          case (io)
            0: begin volledig = ia + ib; ey = volledig; ec = (volledig > 255);
                     volledig = sa + sb; ev = (volledig > 127 || volledig < -128); end
            1: begin volledig = ia - ib; ey = volledig; ec = (ia >= ib);
                     volledig = sa - sb; ev = (volledig > 127 || volledig < -128); end
            2: ey = ia & ib;
            3: ey = ia | ib;
            4: ey = ia ^ ib;
            5: ey = ~a;
            6: begin ey = ia << 1; ec = a[7]; end
            7: begin ey = ia >> 1; ec = a[0]; end
          endcase
          if (y !== ey || c !== ec || v !== ev || z !== (ey == 0) || n !== ey[7]) begin
            fouten = fouten + 1;
            if (fouten < 10)
              $display("FAIL op=%0d a=%h b=%h: y=%h c=%b v=%b z=%b n=%b, verwacht y=%h c=%b v=%b",
                       io, a, b, y, c, v, z, n, ey, ec, ev);
          end
        end
    if (fouten == 0) $display("PASS: ALU klopt voor alle 524288 combinaties van operanden en bewerking");
    $finish;
  end
endmodule
```

Het model berekent de vlaggen op een andere manier dan de hardware: de carry als `volledig > 255` en de overflow door met getallen met teken te rekenen en te kijken of het resultaat buiten −128..127 valt. Delen hardware en model dezelfde denkfout, dan vind je die nooit. Schrijf het model daarom bij voorkeur op een onafhankelijke manier.

### Test van de vergelijkingen

De tabel uit paragraaf 3 is een belofte. We controleren hem voor alle paren.

```verilog
// FILE: week11/tb_compare.v
module tb_compare;
  reg  [7:0] a, b;
  wire [7:0] y;
  wire       z, n, c, v;
  integer ia, ib, fouten = 0;

  alu #(8) dut(a, b, 3'd1, y, z, n, c, v);   // altijd SUB

  initial begin
    for (ia = 0; ia < 256; ia = ia + 1)
      for (ib = 0; ib < 256; ib = ib + 1) begin
        a = ia; b = ib; #1;
        if (z !== (ia == ib))                         begin fouten = fouten + 1; end
        if (c !== (ia >= ib))                         begin fouten = fouten + 1; end
        if ((c && !z) !== (ia > ib))                  begin fouten = fouten + 1; end
        if ((n ^ v) !== ($signed(a) < $signed(b)))    begin fouten = fouten + 1; end
        if (!(n ^ v) !== ($signed(a) >= $signed(b)))  begin fouten = fouten + 1; end
      end
    if (fouten == 0) $display("PASS: alle vergelijkingen via vlaggen kloppen (Z, C, N^V)");
    else             $display("FAIL: %0d afwijkingen", fouten);
    $finish;
  end
endmodule
```

Draai ze:

```text
cd labs/week11
iverilog -g2012 -o a.vvp tb_alu.v alu.v && vvp a.vvp
iverilog -g2012 -o b.vvp tb_compare.v alu.v && vvp b.vvp
```

## 6. Lab op het breadboard: een 4-bit optel/aftrekker

Je hebt nodig: een 74HC283 (4-bit opteller), een 74HC86 (4× XOR), 8 dip-switches, een schakelaar SUB, LED's voor S0 tot S3, C4 en V, en een 74HC04 en 74HC08 voor de V-logica.

Het idee: de XOR laat B ongemoeid (SUB = 0) of keert hem om (SUB = 1). SUB gaat ook naar C0 van de opteller, dat is de "+1".

```text
 B0..B3 ──► XOR met SUB ──► B'0..B'3 ──┐
 A0..A3 ───────────────────────────────┤► 74HC283 ──► S0..S3, C4
 SUB ──────────────────────────────► C0 (carry-in)
```

Bouw en test:

1. Zet SUB = 0. Tel 5 + 3 en 9 + 8 op en lees S en C4 af.
2. Zet SUB = 1. Reken 5 − 3 (moet 2 geven, met C4 = 1) en 3 − 5 (moet 14 = 1110 = −2 geven, met C4 = 0).
3. Bouw de overflowvlag: V = (A3 XNOR B'3) AND (A3 XOR S3). Er is overflow als de tekens van A en de effectieve B gelijk zijn en het teken van het resultaat verschilt. Test 7 + 1 = 8 (in twee-complement −8): V = 1.
4. Bouw Z: een NOR van alle vier S-bits (twee 74HC02's, of een 74HC4002).

Vraag voor je logboek: waarom betekent C4 = 1 hier "geen lening" bij aftrekken?

## 7. Oefeningen

1. Bereken voor 8 bits de vlaggen Z, N, C, V en het resultaat voor: (a) 0x7F + 0x01, (b) 0xFF + 0x01, (c) 0x80 − 0x01, (d) 0x05 − 0x07.
2. Wat is het 8-bit twee-complement van 0x2A? En van 0x80? Wat valt je op bij 0x80?
3. Welke vlaggenconditie gebruik je voor "A < B met teken"? Controleer het met A = −3 en B = 5 in 8 bits.
4. Breid de ALU uit met een negende bewerking `PASS_B` (Y = B) en een tiende `INC` (Y = A + 1). Hoeveel opcode-bits heb je dan nodig?
5. Waarom is de opteller in een ALU meestal het kritieke pad?
6. Voeg een `ROL` (rotate left) toe, waarbij de carry-uit aan de linkerkant weer rechts binnenkomt. Test het.
7. Uitdaging: maak een extra uitgang `gt_s` (signed greater than) in de ALU, berekend uit de vlaggen, en test hem tegen `$signed(a) > $signed(b)`.

## 8. Antwoorden

1. (a) Y = 0x80, N = 1, Z = 0, C = 0, V = 1 (127 + 1 loopt over). (b) Y = 0x00, Z = 1, C = 1, N = 0, V = 0. (c) Y = 0x7F, N = 0, Z = 0, C = 1 (geen lening), V = 1 (−128 − 1 loopt over). (d) Y = 0xFE, N = 1, Z = 0, C = 0 (lening), V = 0.
2. 0x2A = 00101010. Omkeren geeft 11010101 en plus 1 geeft 0xD6. Bij 0x80 geeft omkeren 0x7F en plus 1 weer 0x80. Het getal −128 heeft dus geen positieve tegenhanger in 8 bits: het twee-complement is asymmetrisch (−128 tot +127).
3. N ≠ V na SUB. Controle met A = −3 (0xFD) en B = 5: −3 − 5 = −8 = 0xF8, dus N = 1. De tekens van A en B verschillen en Y heeft hetzelfde teken als A, dus V = 0. N ≠ V klopt: A < B.
4. Met 10 bewerkingen heb je 4 bits nodig (2³ = 8 is te weinig, 2⁴ = 16 is genoeg).
5. Omdat de carry door alle bits moet rippelen (of door een lookahead-boom). De andere bewerkingen (AND, OR, XOR en shift) zijn maar één poortniveau diep.
6. Een extra tak: `ROL: begin y = {a[W-2:0], c_in}; c = a[W-1]; end`, met `c_in` als nieuwe ingang (de carry uit het vlaggenregister). Een test: waarde en carry vormen samen 9 bits, dus negen keer `ROL` achter elkaar, elke keer met de carry van de vorige stap, herstelt de beginwaarde.
7. `gt_s = ~z & ~(n ^ v)`: niet gelijk en niet kleiner dan. Test met `$signed(a) > $signed(b)` over alle paren.

## 9. Zelftest

1. Hoe trek je af met een opteller?
2. Wat betekent C = 1 na een SUB (in onze conventie)?
3. Wat geeft V aan?
4. Welke vlaggen heb je nodig om te testen of signed A < B?
5. Waarom is de ALU combinatorisch?

Antwoorden: (1) A + ~B + 1. (2) Er was geen lening: A ≥ B zonder teken. (3) Het resultaat past niet in twee-complement. (4) N en V (N ≠ V). (5) Hij heeft geen toestand nodig: het resultaat hangt alleen af van de huidige ingangen en de registers erboven onthouden het.

## 10. Verder lezen

- Harris en Harris, 5.2 (rekenkundige schakelingen) en 5.2.4 (ALU).
- Ben Eater: "Arithmetic logic unit" in zijn serie over de 8-bit computer.
- Voor liefhebbers: de 74181, een historische 4-bit ALU in één chip uit 1970. Veel computers uit die tijd zijn eromheen gebouwd.

Volgende week doen we de rest van de rekenkunde: getallen met teken, vaste komma, shifters en vermenigvuldigen.
