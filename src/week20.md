---
title: "Week 20 · Pipelining"
---

<p class="subtitle">Fase 5 · Geavanceerde architecturen · ongeveer 12 uur</p>

# Week 20: Pipelining

## Wat je na deze week kunt

- uitleggen wat pipelining is en waarom het de doorvoer (throughput) verhoogt zonder de latentie te verkorten
- de drie soorten hazards (structureel, data en controle) benoemen
- een CPU met minimale wijzigingen omzetten naar een gepijplijnde variant
- de prestatiewinst berekenen en meten (CPI, aantal verloren cycli)
- begrijpen waarom een tweetrapspipeline weinig problemen heeft en een vijftrapspipeline veel meer

## 1. De wasmachine-vergelijking

Stel dat je wasgoed drie stappen doorloopt: wassen (30 min), drogen (40 min) en vouwen (20 min). Zonder planning doe je één lading in 90 minuten en begin je dan pas aan de volgende. Met overlap begin je meteen aan de tweede lading als de eerste in de droger gaat. Na de eerste lading komt er dan om de 40 minuten (de langzaamste stap) een lading klaar.

```text
 geen overlap:   [was1 droog1 vouw1][was2 droog2 vouw2][was3 ...
 met overlap:    [was1 droog1 vouw1]
                      [was2 droog2 vouw2]
                           [was3 droog3 vouw3]
```

Onthoud twee dingen. De latentie van één lading (de tijd van begin tot eind) wordt niet korter, eerder iets langer. De doorvoer (ladingen per uur) wordt wel veel groter: om de 40 minuten klaar in plaats van om de 90.

Een CPU-instructie doorloopt ook stappen: ophalen, decoderen, uitvoeren, geheugen en terugschrijven. Als je die laat overlappen, kan er elke klokcyclus een instructie klaarkomen.

### De formules

Voor een pipeline met n trappen, waarvan de langzaamste trap T kost:

```text
  klokperiode  ≈  T_langzaamste_trap + overhead van de pipelineregisters
  ideale CPI   =  1 (één instructie per cyclus)
  ideale versnelling t.o.v. een machine met één lange trap  ≈  n
```

Er staat niet voor niets "ideaal": in de praktijk verliezen we cycli aan hazards.

## 2. De drie hazards

Een hazard is een situatie waarin de volgende instructie niet meteen kan beginnen zonder fouten te veroorzaken.

| Soort | Probleem | Voorbeeld |
|-------|----------|-----------|
| Structureel | twee instructies willen tegelijk dezelfde hardware gebruiken | één geheugen voor instructies en data |
| Data | een instructie heeft een resultaat nodig dat nog niet geschreven is | `ADD R1,R2,R3` gevolgd door `SUB R4,R1,R5` |
| Controle | je weet pas laat welke instructie de volgende is | een sprong |

Hoe los je ze op? Bij een stall (wachten) voeg je een lege cyclus ("bubbel") in. Dat is simpel, maar het kost tijd. Bij forwarding (doorsturen) geef je het resultaat direct van het einde van de ene trap door aan de ingang van een andere, zonder te wachten tot het in het registerbestand is geschreven. Met een flush gooi je de instructies weg die je ten onrechte hebt opgehaald. En je kunt voorspellen: raden wat de sprong gaat doen (week 21).

## 3. De klassieke vijftrapspipeline

Veel leerboeken gebruiken deze opbouw:

| Trap | Naam | Taak |
|------|------|------|
| IF | Instruction Fetch | instructie ophalen |
| ID | Instruction Decode | decoderen, registers lezen |
| EX | Execute | ALU, adres berekenen |
| MEM | Memory | geheugen lezen of schrijven |
| WB | Write Back | resultaat in een register zetten |

```text
 cyclus:    1    2    3    4    5    6    7
 instr 1:  IF   ID   EX   MEM  WB
 instr 2:       IF   ID   EX   MEM  WB
 instr 3:            IF   ID   EX   MEM  WB
```

Bij elke grens zit een pipelineregister dat de tussenresultaten vasthoudt. Het ontwerp heeft drie sleutelproblemen, waar we de komende week op ingaan.

- Lees-na-schrijf: instructie 2 leest in ID een register dat instructie 1 pas in WB schrijft, twee cycli later. De oplossing is forwarding.
- Load-gebruik: `LD R1,...` wordt gevolgd door een instructie die R1 meteen gebruikt, maar de waarde bestaat pas na MEM. Zelfs met forwarding moet je één cyclus wachten.
- Sprongen: pas in EX weet je of een sprong genomen wordt. Intussen zijn er al twee instructies opgehaald.

## 4. Onze W8 pipelinen

W8 heeft al twee fasen, ophalen (T0) en uitvoeren (T1), maar die volgen elkaar op, waardoor je twee cycli per instructie nodig hebt. Wat als ze overlappen?

```text
 cyclus:         1     2     3     4     5     6
 instructie 1:  IF    EX
 instructie 2:        IF    EX
 instructie 3:              IF    EX
```

In cyclus 2 voert de CPU instructie 1 uit terwijl hij instructie 2 ophaalt. Dat is één instructie per cyclus, dus CPI 1 in plaats van 2.

### Moet het datapath veranderen?

Bijna niets. Dat is het mooie van een goed ontwerp: het datapath kon al in dezelfde cyclus uitvoeren en de PC ophogen. Er zijn maar twee wijzigingen.

1. De besturing hoeft niet meer te wisselen tussen T0 en T1. In elke cyclus staan `pc_inc` en `ir_we` aan, plus de signalen voor de instructie in het IR.
2. Een genomen sprong gooit de zojuist opgehaalde instructie weg. Die is van de verkeerde plek gehaald. Het IR krijgt een `NOP` in plaats van de gelezen instructie.

### Waarom geen datahazards?

De registers worden aan het einde van de uitvoertrap geschreven. De volgende instructie leest haar registers in haar eigen uitvoertrap, een cyclus later, en dan zijn de nieuwe waarden er al. Dus:

```text
 ADD R1,R2,R3     :  IF  EX(schrijft R1 aan het einde van deze cyclus)
 SUB R4,R1,R5     :      IF  EX(leest R1: nieuwe waarde is er)
```

Hetzelfde geldt voor de vlaggen (een `BNE` direct na een `ADDI` ziet de nieuwe Z-vlag) en voor het geheugen (een `LD` direct na een `ST` naar hetzelfde adres leest de nieuwe waarde). Een tweetrapspipeline met dit ontwerp heeft dus alleen een controlehazard: elke genomen sprong kost één cyclus.

### Wat doen `CALL` en `HALT`?

`CALL` bewaart de PC in R7 en springt. Tijdens de uitvoer van een instructie op adres a staat de PC op a + 1 (de volgende instructie wordt al opgehaald), net als in de niet-gepijplijnde W8. Het terugkeeradres klopt dus zonder wijziging. `CALL` is een genomen sprong en kost dus een flush. `HALT` zet het halt-register, en de instructie die intussen is opgehaald wordt nooit uitgevoerd.

## 5. De implementatie

Je hebt maar twee nieuwe bestanden nodig. Kopieer eerst de bestanden die niet veranderen (`alu.v`, `idecode.v`, `memories.v`, `datapath.v`, `asm_funcs.vh`, `asm.py`, de programma's en de oude `control.v` en `cpu.v` voor de vergelijking) naar de nieuwe map `labs/cpu_pipe/`.


### De besturing: één trap in plaats van twee

Vergelijk dit met `control.v` van week 15. De stapteller `t` is weg en het ophalen (`F_PC_INC | F_IR_WE`) staat bij elke instructie tegelijk met de uitvoering aan.

```{.verilog include="cpu_pipe/control_p.v"}
```

### Het toplevel met de flush

Hier staat de enige echt nieuwe regel: `ir_in = pc_load ? NOP : imem_dout`. Laat de besturing een sprong doorgaan, dan wordt de instructie die tegelijk uit het geheugen komt vervangen door een `NOP`.

```{.verilog include="cpu_pipe/cpu_p.v"}
```

Dat is alles. Het datapath is niet aangeraakt.

## 6. Verificatie

### Dezelfde willekeurige test, met een aangepaste cyclusformule

We hergebruiken de willekeurige test uit week 16 met het referentiemodel. Registers, vlaggen en geheugen moeten identiek zijn aan wat het model voorspelt. Alleen de cyclustelling verandert:

```text
cycli = 1 (pipeline vullen) + aantal instructies + aantal genomen sprongen
```

Elke genomen `Bcc`, `CALL` en `JR` kost één verloren cyclus. De test controleert deze formule voor alle 300 programma's exact. Dat is een sterke controle, want het betekent dat het gedrag van de flush precies begrepen is.

```{.verilog include="cpu_pipe/tb_pipe_random.v"}
```

### De vergelijking op echte programma's

Dezelfde zes programma's uit week 17 draaien op beide CPU's, tegelijk, met een controle dat het resultaat identiek is:

```{.verilog include="cpu_pipe/tb_compare.v"}
```

De meting:

| Programma | W8 (cycli) | W8P (cycli) | Versnelling |
|-----------|-----------:|------------:|:-----------:|
| Som 1..10 | 66 | 43 | 1,53 × |
| 16-bit vermenigvuldigen | 190 | 115 | 1,65 × |
| Bubble sort | 564 | 324 | 1,74 × |
| Priemgetallen | 3596 | 2138 | 1,68 × |
| ggd | 60 | 39 | 1,53 × |
| Subroutines | 114 | 75 | 1,52 × |

De ideale versnelling zou 2,0 zijn. Waar zit het verschil? Neem de som van 1 tot 10: 33 instructies, waarvan 9 genomen sprongen, dus 1 + 33 + 9 = 43 cycli. Programma's met veel lussen en sprongen verliezen meer. De sorteerlus heeft relatief meer rekenwerk per sprong en haalt daarom een hogere versnelling.

## 7. Wat het niet oplost

Let op wat niet is veranderd: de klokperiode. De uitvoertrap van W8P bevat nog steeds het hele pad uit week 14: registers lezen, ALU, geheugen en terugschrijven. De klok kan dus niet sneller dan bij W8. We hebben de CPI verbeterd van 2 naar ongeveer 1,3, maar niet de frequentie.

Een echte snelle processor snijdt dat lange pad in stukken:

```text
 IF  |  ID + registers lezen  |  EX (ALU)  |  MEM  |  WB
```

Elke trap is dan veel korter en de klok kan veel sneller. De prijs is dat er data-hazards verschijnen (week 21).

```text
 tijd = instructies × CPI / frequentie
```

Pipelining kan aan beide kanten van de breuk helpen: de CPI omlaag (zoals hier) of de frequentie omhoog (met meer trappen). Moderne CPU's doen allebei.

## 8. Lab

1. Draai `tb_pipe_random.v` en `tb_compare.v`.
2. Open een golfvorm van het somprogramma op W8P en zoek het moment van de flush. Tel hoeveel cycli er verloren gaan.
3. Verander `cpu_p.v` zodat de flush niet plaatsvindt (`ir_in = imem_dout`). Welke test faalt en hoe?
4. Teken met de hand een tijdschema (cyclus × trap) voor de eerste vijf instructies van `gcd.asm`, met de flush bij elke genomen sprong.
5. Schrijf zelf een programma waar W8P weinig van profiteert (veel genomen sprongen) en een programma waarmee hij bijna een factor 2 haalt (bijna geen sprongen). Meet het met `tb_compare`.

## 9. Oefeningen

1. Een programma voert 1000 instructies uit, waarvan 150 genomen sprongen. Hoeveel cycli kost dat op W8 en op W8P? Wat is de versnelling?
2. Wat is de CPI van W8P bij een sprongfrequentie (genomen sprongen per instructie) van b? Leid een formule af.
3. Een programma is een rechte reeks van 100 instructies zonder sprongen. Wat is de versnelling van W8P?
4. Een vijftrapspipeline heeft de trappen IF 200 ps, ID 150 ps, EX 250 ps, MEM 300 ps en WB 100 ps (pipelineregisters kosten 20 ps). Wat is de klokperiode en wat is de ideale versnelling ten opzichte van één lange trap?
5. Waarom haalt de pipeline uit oefening 4 geen versnelling van 5? Welke trap splits je als eerste en wat wordt dan de klokperiode?
6. Op een vijftrapspipeline staan `ADD R1,R2,R3` en direct daarna `SUB R4,R1,R5`. Teken wanneer R1 beschikbaar is en welke forwarding nodig is.
7. Waarom werkt de pipeline van W8P niet meer als de leesactie van het datageheugen in een aparte trap zit, zonder extra maatregelen?
8. Uitdaging: voeg een derde trap toe aan W8P. De ALU-uitvoer wordt vastgelegd in een register en het terugschrijven en het geheugen gebeuren een cyclus later. Welke hazards ontstaan en hoe lost forwarding ze op?

## 10. Antwoorden

1. W8: 1000 × 2 = 2000 cycli. W8P: 1 + 1000 + 150 = 1151 cycli. De versnelling is 2000 / 1151 ≈ 1,74.
2. CPI(W8P) ≈ (instructies + genomen sprongen) / instructies = 1 + b, waarbij je de enkele vulcyclus verwaarloost. Bij b = 0,2 is de CPI 1,2 en de versnelling 2 / 1,2 ≈ 1,67.
3. W8: 200 cycli. W8P: 1 + 100 = 101 cycli. De versnelling is ongeveer 1,98, praktisch 2.
4. De klokperiode is de langzaamste trap plus de overhead: 300 + 20 = 320 ps. Zonder pipeline (alles in één cyclus) kost een instructie 200 + 150 + 250 + 300 + 100 = 1000 ps. De ideale versnelling is 1000 / 320 ≈ 3,1, en dus geen 5, omdat de trappen ongelijk lang zijn en de pipelineregisters tijd kosten.
5. De klok volgt de langzaamste trap (MEM, 300 ps). Splits je MEM in twee trappen van elk 150 ps, dan is EX de langzaamste trap (250 ps) en wordt de klokperiode 270 ps. Daarna is EX de volgende kandidaat om te splitsen.
6. De som is aan het einde van EX klaar (cyclus 3 voor `ADD`). `SUB` heeft R1 nodig aan het begin van zijn EX (cyclus 4). Forwarding stuurt de ALU-uitvoer van de vorige instructie in cyclus 4 rechtstreeks naar de ingang van de ALU, zonder te wachten op WB (cyclus 5).
7. Een `LD` gevolgd door een instructie die het geladen register meteen gebruikt, krijgt de waarde pas een trap later. Dan moet je één cyclus wachten (stall), ook met forwarding. Dit heet het load-gebruikprobleem.
8. Er ontstaat een data-hazard: de instructie na `ADD` ziet het resultaat nog niet in het registerbestand. De oplossing is forwarding van het ALU-uitgangsregister naar de ALU-ingangen, met vergelijkers die controleren of de bronregisters gelijk zijn aan de bestemming van de instructie ervoor. Na een `LD` blijft één stall nodig.

## 11. Zelftest

1. Wat doet pipelining met latentie en doorvoer?
2. Welke drie soorten hazards zijn er?
3. Waarom heeft de tweetraps W8P geen data-hazards?
4. Wat kost een genomen sprong in W8P?
5. Wat is forwarding?

Antwoorden: (1) De latentie van één instructie blijft gelijk of wordt iets langer, de doorvoer neemt toe. (2) Structureel, data en controle. (3) Registers worden aan het einde van EX geschreven en de volgende instructie leest pas in haar eigen EX. (4) Eén verloren cyclus (de flush). (5) Een resultaat direct van de ene trap naar de ingang van een andere sturen, zonder te wachten op het registerbestand.

## 12. Verder lezen

- Patterson en Hennessy, *Computer Organization and Design*, hoofdstuk 4 (de vijftrapspipeline).
- Harris en Harris, hoofdstuk 7.5 (de pipelineprocessor).
- Hennessy en Patterson, *Computer Architecture: A Quantitative Approach*, bijlage C (pipelining).

Volgende week: we bekijken de hazards in detail, bouwen een branch-predictorsimulator in Python en ontwerpen een cache in Verilog.
