---
title: "Week 7 · Toestandsmachines (FSM's)"
---

<p class="subtitle">Fase 2 · Geheugen en tijd · ongeveer 11 uur</p>

# Week 7: Toestandsmachines

## Wat je na deze week kunt

- een toestandsdiagram tekenen voor een probleem
- het verschil uitleggen tussen een Moore- en een Mealy-machine
- een FSM in Verilog schrijven in de vaste stijl met drie blokken
- toestanden coderen (binair, one-hot) en de gevolgen daarvan inschatten
- uitleggen waarom de besturingseenheid van een CPU een FSM is

## 1. Wat is een FSM?

Een finite state machine (eindige toestandsmachine) is een schakeling met een toestand, opgeslagen in een register, en ingangen. Een regel bepaalt uit de huidige toestand en de ingangen de volgende toestand. De uitgangen volgen uit de toestand en soms ook uit de ingangen.

Een teller is een FSM met de toestanden 0, 1, 2 enzovoort. Een verkeerslicht is er ook een, en een kaartjesautomaat. En de besturingseenheid van een CPU doorloopt de toestanden instructie ophalen, decoderen, uitvoeren en wegschrijven.

```text
        ingangen ──►┌─────────────────┐
                    │  volgende-      │──► D ──►┌────────────┐──► toestand
        toestand ──►│  toestand logica│         │ toestand-  │       │
          ▲         └─────────────────┘         │ register   │       │
          └───────────────────────────────────────────────────────────┘
                                                 (klok)
        toestand (en ingangen) ──►┌────────────┐──► uitgangen
                                  │ uitgangs-  │
                                  │ logica     │
                                  └────────────┘
```

Er zijn dus drie delen: een register (het geheugen), de volgende-toestandslogica (combinatorisch) en de uitgangslogica (combinatorisch). Je kent dit patroon al uit week 4 tot 6.

## 2. Moore en Mealy

| | Moore | Mealy |
|---|-------|-------|
| De uitgang hangt af van | alleen de toestand | toestand en ingangen |
| De uitgang verandert | direct na de klokflank | zodra de ingang verandert, dus ook tussen flanken |
| Aantal toestanden | vaak iets meer | vaak minder |
| Stabiliteit | uitgangen zijn glitchvrij | uitgangen kunnen meebewegen met ruis op de ingang |

In de praktijk kiezen ontwerpers meestal voor Moore, omdat de uitgangen stabiel zijn en makkelijk te timen. Wij doen dat ook, tenzij er een reden is voor Mealy.

## 3. Voorbeeld: een reeksdetector

De opdracht: een machine krijgt bij elke klokflank één bit. Hij geeft `1` zodra de laatste vier bits 1011 waren. Overlap is toegestaan: in `1011011` komt 1011 twee keer voor.

### Stap 1: het toestandsdiagram

We bedenken wat de machine moet onthouden: hoeveel van het patroon er tot nu toe klopt.

| Toestand | Betekenis |
|----------|-----------|
| S0 | nog niets bruikbaars gezien |
| S1 | het laatste bit was `1` |
| S2 | de laatste bits waren `10` |
| S3 | de laatste bits waren `101` |
| S4 | de laatste bits waren `1011`: gevonden (uitgang = 1) |

| Toestand | invoer 0 | invoer 1 |
|----------|:--------:|:--------:|
| S0 | S0 | S1 |
| S1 | S2 | S1 |
| S2 | S0 | S3 |
| S3 | S2 | S4 |
| S4 | S2 | S1 |

Kijk goed naar de overgangen vanuit S3 en S4. Na `1010` zit je op `10` (S2), en na `1011` kan het volgende bit meteen het begin van een nieuw patroon zijn. Zulke details maken van FSM-ontwerp een vak. Teken eerst en codeer daarna.

### Stap 2: de Verilog in drie blokken

```verilog
// FILE: week07/seqdet.v
module seqdet(
  input  clk,
  input  rst_n,
  input  in,
  output detected
);
  localparam S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, S4 = 3'd4;

  reg [2:0] state, next;

  // Blok 1: het toestandsregister (sequentieel).
  always @(posedge clk or negedge rst_n)
    if (!rst_n) state <= S0;
    else        state <= next;

  // Blok 2: volgende-toestandslogica (combinatorisch).
  always @* begin
    next = S0;                       // standaardwaarde: voorkomt latches
    case (state)
      S0: next = in ? S1 : S0;
      S1: next = in ? S1 : S2;
      S2: next = in ? S3 : S0;
      S3: next = in ? S4 : S2;
      S4: next = in ? S1 : S2;
      default: next = S0;            // ongeldige toestanden vangen we op
    endcase
  end

  // Blok 3: uitgangslogica (Moore: alleen van de toestand afhankelijk).
  assign detected = (state == S4);
endmodule
```

Drie dingen om te onthouden. Het toestandsregister gebruikt `<=` en een klok, de twee combinatorische blokken gebruiken `=` en `always @*`. Geef `next` altijd een standaardwaarde vóór de `case` en zet een `default`-tak erbij, anders ontstaat een latch (geheugen dat je niet wilde) en waarschuwt je synthesistool je. En de ongebruikte toestanden (5, 6 en 7) moeten ergens naartoe gaan. Een stoorpuls kan de machine erin duwen, en dan moet hij zich herstellen.

### De test

Een goede testbench vergelijkt met een referentiemodel, een simpel en vanzelfsprekend correct stukje gedrag. Hier houden we gewoon de laatste vier bits bij en vergelijken we ze met `1011`. Daarna voeren we 500 willekeurige bits in.

```verilog
// FILE: week07/tb_seqdet.v
module tb_seqdet;
  reg clk = 0, rst_n = 0, in = 0;
  wire detected;
  reg [3:0] hist = 0;
  integer i, fouten = 0, gevonden = 0;

  seqdet dut(clk, rst_n, in, detected);
  always #5 clk = ~clk;

  initial begin
    #12 rst_n = 1;
    for (i = 0; i < 500; i = i + 1) begin
      @(negedge clk);
      in = $random;
      @(posedge clk);                // de machine neemt 'in' over
      hist = {hist[2:0], in};        // referentiemodel: laatste 4 bits
      #1;
      if (detected !== (hist == 4'b1011 && i >= 3)) begin
        fouten = fouten + 1;
        $display("FAIL bij bit %0d: hist=%b detected=%b", i, hist, detected);
      end
      if (detected) gevonden = gevonden + 1;
    end
    $display("(%0d keer 1011 gevonden in 500 bits)", gevonden);
    if (fouten == 0 && gevonden > 5) $display("PASS: reeksdetector klopt, inclusief overlap");
    $finish;
  end
endmodule
```

## 4. Voorbeeld: een verkeerslicht

Er zijn vier toestanden: Noord-Zuid groen, Noord-Zuid geel, Oost-West groen en Oost-West geel. De duur verschilt per toestand, dus we hebben een timer nodig. Het toestandsregister blijft zoals het was, maar de volgende toestand verschijnt pas als de timer afloopt.

```verilog
// FILE: week07/traffic.v
module traffic #(parameter G = 5, parameter Y = 2) (
  input        clk,
  input        rst_n,
  output reg [1:0] ns,    // 00 rood, 01 geel, 10 groen
  output reg [1:0] ew
);
  localparam NSG = 2'd0, NSY = 2'd1, EWG = 2'd2, EWY = 2'd3;

  reg [1:0] state, next;
  reg [7:0] t;
  wire [7:0] duur = (state == NSG || state == EWG) ? G : Y;
  wire       klaar = (t == duur - 1);

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin state <= NSG; t <= 0; end
    else if (klaar) begin state <= next; t <= 0; end
    else t <= t + 1'b1;

  always @* begin
    case (state)
      NSG: next = NSY;
      NSY: next = EWG;
      EWG: next = EWY;
      default: next = NSG;
    endcase
  end

  always @* begin
    case (state)
      NSG: begin ns = 2'b10; ew = 2'b00; end
      NSY: begin ns = 2'b01; ew = 2'b00; end
      EWG: begin ns = 2'b00; ew = 2'b10; end
      default: begin ns = 2'b00; ew = 2'b01; end
    endcase
  end
endmodule
```

```verilog
// FILE: week07/tb_traffic.v
module tb_traffic;
  reg clk = 0, rst_n = 0;
  wire [1:0] ns, ew;
  integer i, fouten = 0;
  reg [3:0] verwacht [0:13];       // {ns, ew} voor één volledige cyclus (5+2+5+2 = 14)

  traffic #(5, 2) dut(clk, rst_n, ns, ew);
  always #5 clk = ~clk;

  initial begin
    for (i = 0;  i < 5;  i = i + 1) verwacht[i] = 4'b10_00;   // NS groen
    for (i = 5;  i < 7;  i = i + 1) verwacht[i] = 4'b01_00;   // NS geel
    for (i = 7;  i < 12; i = i + 1) verwacht[i] = 4'b00_10;   // EW groen
    for (i = 12; i < 14; i = i + 1) verwacht[i] = 4'b00_01;   // EW geel
    #12 rst_n = 1;
    for (i = 0; i < 42; i = i + 1) begin      // drie cycli
      #1;
      if ({ns, ew} !== verwacht[i % 14]) begin
        fouten = fouten + 1;
        $display("FAIL stap %0d: ns=%b ew=%b", i, ns, ew);
      end
      @(posedge clk); #1;
    end
    if (fouten == 0) $display("PASS: verkeerslicht doorloopt de juiste volgorde en duur");
    $finish;
  end
endmodule
```

## 5. Toestanden coderen

Hoe stel je de toestanden voor in bits?

| Codering | S0 | S1 | S2 | S3 | S4 | Bits | Eigenschap |
|----------|----|----|----|----|----|------|------------|
| Binair | 000 | 001 | 010 | 011 | 100 | log₂(n) | minste flipflops, meer logica |
| One-hot | 00001 | 00010 | 00100 | 01000 | 10000 | n | veel flipflops, weinig logica, snel |
| Gray | 000 | 001 | 011 | 010 | 110 | log₂(n) | opeenvolgende toestanden verschillen in één bit |

In een FPGA kies je meestal one-hot, want flipflops zijn er in overvloed en logica is duur. Bij zelfgebouwde 74HC-schakelingen is binair vaak praktischer, omdat het minder chips kost. Moderne synthesistools kunnen de codering voor je veranderen. Jij schrijft de leesbare versie.

## 6. FSM's in een CPU

De besturingseenheid van de eenvoudigste CPU is een FSM met drie toestanden:

```text
      ┌────────┐     ┌────────┐     ┌─────────┐
      │ FETCH  │────►│ DECODE │────►│ EXECUTE │──┐
      └────────┘     └────────┘     └─────────┘  │
           ▲                                      │
           └──────────────────────────────────────┘
```

Bij fetch lees je de instructie uit het geheugen, zet je hem in het instructieregister en verhoog je de programmateller. Bij decode kijk je wat de instructie vraagt. Bij execute voer je het uit: je stuurt de ALU aan en schrijft het resultaat weg.

De uitgangen van deze FSM zijn de besturingssignalen (`pc_enable`, `alu_op`, `reg_write` en zo verder). In week 15 bouwen we dit.

## 7. Lab op het breadboard

Je hebt nodig: een 74HC161, 74HC00/08/32/04 voor de decodering, 6 LED's (rood, geel en groen voor twee richtingen) met 330 Ω en de klok uit week 6.

Voor het verkeerslicht kun je een teller als toestandsgeheugen gebruiken. De 74HC161 telt van 0 tot 13 (laad 0 zodra de teller 13 bereikt). Een paar poorten decoderen dat: tellerwaarde 0 tot 4 is NS groen, 5 en 6 is NS geel, 7 tot 11 is EW groen en 12 en 13 is EW geel. Leid met K-maps (week 3) de LED-signalen af uit de vier tellerbits.

Dit leert je iets bruikbaars: een FSM is vaak een teller met combinatorische logica eromheen. De programmateller van een CPU is hetzelfde idee.

## 8. Oefeningen

1. Teken het toestandsdiagram van een machine die twee opeenvolgende enen detecteert (patroon 11, overlap toegestaan). Hoeveel toestanden heb je nodig?
2. Maak van de reeksdetector 1011 een Mealy-machine. Hoeveel toestanden heb je dan nodig, en wanneer gaat de uitgang hoog in vergelijking met de Moore-versie?
3. Ontwerp een automaat die muntjes van 5 en 10 cent accepteert en bij 15 cent een product geeft. Teken het diagram (Moore). Welke toestanden heb je?
4. Waarom is een `default` in de `case` van de volgende-toestandslogica belangrijk?
5. Een FSM heeft 12 toestanden. Hoeveel flipflops heb je nodig in binaire en in one-hot codering?
6. Schrijf de Verilog van de 11-detector uit oefening 1 en test hem met een referentiemodel.
7. Uitdaging: ontwerp een stoplicht met een voetgangersknop. Normaal blijft Noord-Zuid groen. Als iemand op de knop drukt, gaat het via geel naar rood voor NS en groen voor EW (de voetgangers) gedurende vijf cycli, en daarna terug.

## 9. Antwoorden

1. Drie toestanden: A (geen 1 gezien), B (het laatste bit was 1) en C (twee enen achter elkaar, uitgang 1). A: 0→A, 1→B. B: 0→A, 1→C. C: 0→A, 1→C (overlap).
2. Mealy heeft 4 toestanden nodig (S0 tot en met S3), omdat de uitgang bij de overgang van S3 met invoer 1 hoog wordt. De Mealy-uitgang is één klokperiode eerder zichtbaar: zodra de laatste 1 binnenkomt, niet pas na de flank.
3. De toestanden zijn 0 cent, 5 cent, 10 cent en 15 cent (uitgang: product). Elke toestand heeft overgangen voor +5 en +10. Bij 15 cent gaat de machine terug naar 0. Wat je bij 20 cent doet (geld terug of weigeren) is een extra toestand of regel.
4. Zonder `default` kan de synthesistool een latch maken, of blijft een ongeldige toestand (door ruis of een stroomstoot) ongedefinieerd. Met `default` valt de machine terug naar een bekende toestand.
5. Binair: ⌈log₂ 12⌉ = 4 flipflops. One-hot: 12.
6. Volg de aanpak van de reeksdetector, nu met drie toestanden. Als referentiemodel werkt `hist[1:0] == 2'b11`.
7. Maak een toestand per fase (NS groen en wachtend, NS geel, EW groen voor voetgangers, EW geel) en gebruik de knop als ingang in de eerste toestand. Je hebt een geheugenbit "knop ingedrukt" nodig (gesynchroniseerd, zie week 6), anders mist de machine korte indrukken.

## 10. Zelftest

1. Uit welke drie delen bestaat een FSM?
2. Wat is het verschil tussen Moore en Mealy?
3. Waarom schrijf je een default-toestand?
4. Wanneer kies je one-hot codering?
5. Wat doet de besturingseenheid van een CPU?

Antwoorden: (1) Toestandsregister, volgende-toestandslogica en uitgangslogica. (2) Bij Moore hangt de uitgang alleen van de toestand af, bij Mealy ook van de ingangen. (3) Om latches en ongedefinieerd gedrag te voorkomen en een herstelpad te hebben. (4) Bij FPGA's, waar flipflops goedkoop zijn en snelheid telt. (5) Hij loopt als FSM door de stappen fetch, decode en execute en stuurt de rest van de CPU aan.

## 11. Verder lezen

- Harris en Harris, 3.4 (toestandsmachines) en 4.6 (FSM's in HDL).
- Ben Eater: "Control logic" in zijn 8-bit-computerreeks. Dat is een FSM met een microcode-ROM, en zo eentje maken we in week 15 zelf.
- Zoek een online FSM-ontwerper op ("fsm designer") om diagrammen mee te tekenen.

Volgende week bouwen we het laatste ontbrekende stuk van fase 2: het geheugen, en de bus waarmee alles met elkaar praat.
