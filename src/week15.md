---
title: "Week 15 · De besturingseenheid en microcode"
---

<p class="subtitle">Fase 4 · Je eerste CPU · ongeveer 12 uur</p>

# Week 15: De besturingseenheid en microcode

## Wat je na deze week kunt

- uitleggen hoe de besturing een instructie in twee stappen uitvoert
- een controlewoord en een controlegeheugen (control store) ontwerpen
- het verschil uitleggen tussen hardwired en microgeprogrammeerde besturing
- de logica voor voorwaardelijke sprongen bouwen
- een nieuwe instructie toevoegen door één regel in het controlegeheugen te schrijven
- de complete W8-CPU samenvoegen en testen

## 1. De cyclus: ophalen en uitvoeren

Elke instructie van W8 duurt twee klokcycli. De besturing is een toestandsmachine (week 7) met één bit toestand, `t`:

| Stap | `t` | Wat gebeurt er |
|------|:---:|----------------|
| T0, ophalen | 0 | het instructieregister laadt de instructie op adres PC en de PC gaat 1 omhoog |
| T1, uitvoeren | 1 | het datapath doet wat de opcode vraagt |

```text
 klok:   ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
          └─┘ └─┘ └─┘ └─┘ └─┘ └─┘
 stap:   | T0 | T1 | T0 | T1 | T0 | T1 |
 instr.: |  instructie 1  |  instructie 2  | ...
```

De PC gaat al in T0 omhoog. Daardoor staat tijdens T1 in de PC het adres van de volgende instructie. Dat is precies wat `CALL` als terugkeeradres nodig heeft, en een sprong overschrijft die waarde gewoon.

De uitgangen van deze toestandsmachine zijn de 13 besturingssignalen van het datapath. De vraag is hoe we ze berekenen.

## 2. Het controlewoord

Voor elke combinatie van (opcode, stap) moet je kiezen welke signalen aan staan. Dat is een tabel, en tabellen kennen we: een ROM (week 8). We bundelen alle signalen in één controlewoord van 20 bit:

| Bit | Signaal | Bit | Signaal |
|:---:|---------|:---:|---------|
| 0 | `pc_inc` | 10 | `mem_we` |
| 1 | `pc_load` | 11 | `cc` (laden alleen als de voorwaarde klopt) |
| 2 | `pc_src` | 12-13 | `wb_sel` |
| 3 | `ir_we` | 14-15 | `b_sel` |
| 4 | `reg_we` | 16-18 | `alu_op` |
| 5 | `wa_r7` | 19 | `halt` |
| 6 | `ra_sel` | | |
| 7 | `rb_sel` | | |
| 8 | `alu_ir` | | |
| 9 | `flags_we` | | |

Het controlegeheugen:

| Opcode | Stap T0 | Stap T1 (uitvoeren) |
|--------|---------|---------------------|
| ALU | `pc_inc`, `ir_we` | `alu_ir`, `reg_we`, `flags_we` |
| LDI | idem | `reg_we`, `wb_sel`=imm |
| ADDI | idem | `ra_sel`, `b_sel`=imm, `reg_we`, `flags_we` |
| LD | idem | `b_sel`=off, `reg_we`, `wb_sel`=mem |
| ST | idem | `b_sel`=off, `rb_sel`, `mem_we` |
| Bcc | idem | `pc_load`, `cc` |
| CMP | idem | `alu_op`=SUB, `flags_we` |
| CMPI | idem | `ra_sel`, `b_sel`=imm, `alu_op`=SUB, `flags_we` |
| CALL | idem | `pc_load`, `reg_we`, `wa_r7`, `wb_sel`=PC |
| JR | idem | `pc_load`, `pc_src` |
| HALT | idem | `halt` |
| NOP, vrij | idem | (niets) |

Dit is het hele brein van de CPU. Het past op één pagina.

## 3. Hardwired of microcode?

| | Hardwired | Microgeprogrammeerd |
|--|-----------|---------------------|
| Hoe | poorten en een toestandsmachine, met de hand geoptimaliseerd | een ROM met controlewoorden, plus een teller |
| Snelheid | sneller | iets trager (ROM-toegang) |
| Aanpassen | de hardware wijzigen | de ROM-inhoud wijzigen |
| Complexe instructies | moeilijk | eenvoudig: meerdere microstappen |
| Typisch voor | RISC-chips | CISC-chips, zoals x86 en de IBM System/360 |

IBM voerde in de jaren zestig microcode in om één ISA op veel verschillende machines te kunnen aanbieden. Intel gebruikt het nog steeds. Moderne Intel-chips krijgen microcode-updates die bugs in de CPU repareren zonder nieuwe hardware. Dat is de kracht van het idee: de besturing is data.

De W8-besturing is een klein controlegeheugen. In Verilog schrijven we het als een `case`, die de synthesetool op eigen wijze uitrolt (als ROM of als poorten). Op een breadboard zou je er een echte EEPROM voor gebruiken, zoals Ben Eater.

## 4. De besturingseenheid in Verilog

```{.verilog include="cpu/control.v"}
```

Lees het rustig door. De localparams `F_...` geven elke bit een naam, dus een controlewoord als `F_REG_WE | F_WB_IMM` leest als gewoon Nederlands. De `case` is het controlegeheugen: het ontwerp van de CPU staat in die tien regels. `cond_ok` evalueert de acht voorwaarden uit de tabel van week 13 tegen de vlaggen. In `pc_load = cw[1] & (~cw[11] | cond_ok)` gaat een sprong door als hij onvoorwaardelijk is (`cw[11] = 0`) of als de voorwaarde klopt. En `halt_r` zorgt dat de toestandsmachine na `HALT` stopt en het controlewoord 0 wordt, zodat er niets meer verandert.

> **Een valkuil in simulatie: `always_comb` of `always @*`?** Een `always @*`-blok draait alleen als een van zijn ingangen verandert. Hebben `cond` en de vlaggen vanaf tijd nul al hun beginwaarde en veranderen ze nooit, dan draait het blok nooit en blijft de uitgang (hier `cond_ok`) op X staan, ook al is het ontwerp correct. `always_comb` (SystemVerilog) draait één keer bij tijd nul. Echte hardware heeft dit probleem niet, het is een eigenaardigheid van de simulatie. Als je het niet kent, kost het je uren. Gebruik daarom `always_comb` voor combinatorische logica.

## 5. De CPU: alles samen

Het toplevel verbindt datapath, besturing en geheugens:

```{.verilog include="cpu/cpu.v"}
```

Dit is de hele machine. Er zijn vijf modules: `alu`, `idecode`, `datapath`, `control` en de geheugens `imem` en `dmem`. De ingewikkelde dingen zitten in de details van elk onderdeel, het geheel is overzichtelijk.

## 6. De test van de besturing

De testbench controleert voor elke opcode de uitvoerstap tegen de tabel van paragraaf 2, de ophaalstap voor alle opcodes, alle 128 combinaties van voorwaarde en vlaggen en het gedrag van `HALT`.

```{.verilog include="cpu/tb_control.v"}
```

Draai:

```text
cd labs/cpu
iverilog -g2012 -o ctl.vvp tb_control.v control.v
vvp ctl.vvp
```

## 7. Lab: voeg een instructie toe

Dit is het mooie van microcode: een nieuwe instructie is vaak maar één regel. Voeg `SKIP` toe, een instructie die de eerstvolgende instructie overslaat (handig voor korte voorwaardelijke stukjes).

1. Kies een vrije opcode: 0xE. (De opcodes B, C en D worden in week 22 gebruikt voor interrupts.)
2. Voeg in `control.v` `OP_SKIP = 4'hE` toe aan de localparams en in de `case` een regel:
   ```text
   OP_SKIP: cw = F_PC_INC;      // de PC gaat nog een keer omhoog
   ```
3. Test met een programma: `LDI R1,1` / `SKIP` / `LDI R1,2` / `HALT`. R1 moet daarna 1 zijn.

Meer is het niet. Je hebt geen nieuwe hardware nodig, alleen een nieuwe regel in het controlegeheugen. Schrijf de testbench zelf met de `I_...`-functies uit week 13 (het woord voor `SKIP` is `16'hE000`).

## 8. Oefeningen

1. Bereken het controlewoord voor de uitvoerstap van `ADDI` als hexadecimaal getal, met de waarden van de `F_...`-constanten uit `control.v`.
2. Hoeveel bits is het controlegeheugen als ROM (16 opcodes × 2 stappen × 20 bits)? Hoeveel 8-bit EEPROM's heb je nodig voor een breadboardversie?
3. Voeg `SKIP` toe en test het. Schrijf de testbench.
4. Waarom wordt de PC al in T0 verhoogd en niet in T1?
5. Waarom heeft `HALT` een eigen register `halt_r` nodig? Kon het niet gewoon met `t`?
6. Stel dat het instructiegeheugen synchroon leest (zoals blok-RAM in een FPGA): de uitvoer verschijnt een klokflank na het adres. Wat moet je aan de besturing veranderen?
7. Wat gebeurt er als een programma een van de nog ongebruikte opcodes (B tot en met E) tegenkomt? Is dat gewenst? Hoe vang je het af?
8. Uitdaging: maak de besturing driecyclisch voor `LD` (ophalen, adres berekenen, geheugen lezen en naar het register schrijven), met een tussenregister voor het adres. Wat moet je aan het datapath toevoegen?

## 9. Antwoorden

1. `F_RA_RD` (0x00040) + `F_B_IMM` (0x04000) + `F_REG_WE` (0x00010) + `F_FLAGS` (0x00200) = 0x04250.
2. 32 woorden × 20 bit = 640 bit (80 byte). Met 8-bit EEPROM's heb je er 3 nodig (24 bit, waarvan 20 gebruikt). Veel ontwerpers gebruiken een EEPROM met een grotere adresruimte en spreiden de woorden, maar het aantal chips blijft 3 voor de breedte.
3. Zie paragraaf 7. Controle: R1 is 1 na afloop.
4. Dan is de PC al goed (de volgende instructie) tijdens T1. Een sprong overschrijft hem, en `CALL` kan hem direct als terugkeeradres bewaren. Er is ook geen aparte "PC+1"-opteller nodig tijdens T1.
5. Omdat `t` altijd blijft wisselen. `HALT` moet de machine blijvend stoppen, en daarvoor is een eigen geheugen (`halt_r`) nodig.
6. De instructie is dan niet meer in dezelfde cyclus beschikbaar. Je kunt een extra ophaalcyclus toevoegen (drie stappen per instructie), of het instructieregister zelf het uitgangsregister van het geheugen laten zijn. In beide gevallen verschuift de stap waarop het IR geldig is.
7. Ze gedragen zich als `NOP`. Dat is veilig, maar kan fouten maskeren. Beter is een signaal "illegale instructie" dat de CPU laat stoppen of een foutvlag zet, zodat een bug zichtbaar wordt.
8. Een adresregister (MAR) dat het ALU-resultaat bewaart tussen stap 2 en 3. Stap 3 gebruikt dat register als geheugenadres. De besturing krijgt een extra toestand en het controlegeheugen een derde kolom.

## 10. Zelftest

1. Wat doet de besturing in stap T0?
2. Wat is een controlewoord?
3. Wat is het voordeel van microcode?
4. Waarom is `HALT` blijvend?
5. Waarom verhogen we de PC in T0?

Antwoorden: (1) Het instructieregister laden en de PC ophogen. (2) Een bitvector die voor één klokcyclus alle besturingssignalen vastlegt. (3) Je past gedrag aan door data te veranderen, niet hardware, en complexe instructies zijn eenvoudig. (4) Zijn eigen register `halt_r` houdt de stop vast. (5) Dan staat het adres van de volgende instructie klaar voor `CALL`, en sprongen hoeven niets bijzonders te doen.

## 11. Verder lezen

- Harris en Harris, 7.4 (multicyclusprocessor) en 7.7 (microprogrammering).
- Ben Eater: de video's over microcode en over het bouwen van een EEPROM-programmer. Zo programmeer je een controlegeheugen echt.
- Het verhaal van Maurice Wilkes, die microprogrammering in 1951 bedacht.

Volgende week hebben we alle onderdelen. Tijd om de CPU echte programma's te laten draaien en zijn gedrag grondig te controleren.
