---
title: "Week 28 · Het framebuffer: pixels in geheugen"
---

<p class="subtitle">Fase 7 · De beeldcomputer · ongeveer 14 uur</p>

# Week 28: Het framebuffer

## Wat je na deze week kunt

- uitrekenen hoeveel geheugen een beeld kost en daar een resolutie en kleurdiepte bij kiezen
- uitleggen wat een palette is en waarom een beeld van 16 kleuren maar 4 bit per pixel kost
- een framebuffer met twee klokken (CPU en pixelklok) bouwen en uitleggen waarom dat kan
- een pijplijn uitlijnen als een geheugen een klok vertraging toevoegt
- de CPU pixels laten tekenen via een geheugengemapte poort met auto-increment

<!-- COPY cpu_fpga/alu.v beeld/alu.v -->
<!-- COPY cpu_fpga/idecode.v beeld/idecode.v -->
<!-- COPY cpu_fpga/memories.v beeld/memories.v -->
<!-- COPY cpu_fpga/memories_f.v beeld/memories_f.v -->
<!-- COPY cpu_fpga/datapath_i.v beeld/datapath_i.v -->
<!-- COPY cpu_fpga/control_f.v beeld/control_f.v -->
<!-- COPY cpu_fpga/mmio_f.v beeld/mmio_f.v -->
<!-- COPY cpu_fpga/asm.py beeld/asm.py -->
<!-- COPYSED cpu_fpga/cpu_f.v beeld/cpu_v.v "// FILE: cpu_fpga/cpu_f.v"=>"// FILE: beeld/cpu_v.v" "module cpu_f #("=>"module cpu_v #(" "output [7:0]  gpio_out"=>"output [7:0]  gpio_out,
  input         vblank,
  output        fb_we,
  output [13:0] fb_waddr,
  output [7:0]  fb_wdata" "mmio_f #("=>"mmio_v #(" "txd, rxd, gpio_in, gpio_out, irq);"=>"txd, rxd, gpio_in, gpio_out, irq, vblank, fb_we, fb_waddr, fb_wdata);" -->

## 1. Hoeveel geheugen is een beeld?

Vorige week kwam het beeld uit een formule. Nu moet het uit het geheugen komen, zodat de CPU het kan veranderen. Het geheugen dat het beeld bevat heet het framebuffer. Het probleem is de grootte.

Een scherm van 640 x 480 heeft 307 200 pixels. Met 12 bit kleur per pixel (4 bit per kanaal) is dat 3,7 Mbit, ongeveer 460 KB. De iCE40 UP5K heeft maar 120 kbit blok-RAM. Het past er niet in, met een factor dertig.

| Keuze | Bits | Bytes | Past in 120 kbit? |
|-------|-----:|------:|:-----------------:|
| 640 x 480, 12 bit | 3 686 400 | 460 800 | nee |
| 640 x 480, 4 bit | 1 228 800 | 153 600 | nee |
| 320 x 240, 4 bit | 307 200 | 38 400 | nee |
| 160 x 120, 4 bit | 76 800 | 9 600 | ja |
| 160 x 120, 1 bit | 19 200 | 2 400 | ja |

We kiezen 160 x 120 pixels met 16 kleuren (4 bit). Elke pixel van ons beeld is een blok van 4 x 4 schermpixels: de monitor loopt nog steeds 640 x 480 af, maar we lezen het geheugen maar één keer per vier pixels in beide richtingen. Dat is grof (zo zagen computers uit de jaren tachtig eruit), maar voor foto's van een SD-kaart en voor spelletjes is het genoeg, en het past met ruimte over.

## 2. Een palette

Vier bit per pixel geeft 16 verschillende waarden, maar de monitor wil 12 bit kleur. Daar zit een vertaaltabel tussen: de palette. De waarde in het geheugen is geen kleur, maar een nummer. Het nummer wijst een van 16 kleuren aan, en elke kleur heeft 12 bit.

| Nr | Kleur | RGB (4 bit) | Nr | Kleur | RGB (4 bit) |
|:--:|-------|:-----------:|:--:|-------|:-----------:|
| 0 | zwart | 000 | 8 | donkergrijs | 555 |
| 1 | blauw | 00A | 9 | lichtblauw | 55F |
| 2 | groen | 0A0 | 10 | lichtgroen | 5F5 |
| 3 | cyaan | 0AA | 11 | lichtcyaan | 5FF |
| 4 | rood | A00 | 12 | lichtrood | F55 |
| 5 | magenta | A0A | 13 | lichtmagenta | F5F |
| 6 | bruin | A50 | 14 | geel | FF5 |
| 7 | lichtgrijs | AAA | 15 | wit | FFF |

Dit zijn de 16 standaardkleuren van de EGA-kaart uit 1984, met een bruin en twee grijstinten. In `video_out.v` staat de tabel als een `case`: de synthesetool maakt er een kleine ROM van.

## 3. Hoe de pixels in het geheugen staan

Een byte is 8 bit en een pixel is 4 bit, dus er passen twee pixels in een byte. Het linker blok staat in de hoge nibble, het rechter in de lage. Een rij van 160 blokken is 80 bytes, en het hele beeld is 120 x 80 = 9 600 bytes.

```text
   byte 0       byte 1             byte 79
  ┌────┬────┐ ┌────┬────┐       ┌────┬────┐
  │ P0 │ P1 │ │ P2 │ P3 │  ...  │P158│P159│   rij 0
  └────┴────┘ └────┴────┘       └────┴────┘
   hoog laag
  byte 80 begint rij 1, enzovoort.
```

De monitor loopt pixels af met coördinaten `x` en `y`. Het geheugenadres volgt uit het blok waarin die pixel ligt:

```text
  bx = x / 4          (0 tot 159: de kolom van het blok)
  by = y / 4          (0 tot 119: de rij van het blok)
  adres = by · 80 + bx / 2         de nibble: bx even → hoge nibble, bx oneven → lage
```

Delen door 4 en 2 zijn schuiven, en 80 is geen macht van twee. We schrijven `by · 80` als `by · 64 + by · 16`, twee schuifbewerkingen en een optelling. Dat is heel goedkoop in hardware (alleen draden en een opteller) en geeft geen vermenigvuldiger.

## 4. Twee klokken

De CPU draait op 12 MHz en het beeld op 25,125 MHz. Het framebuffer moet door allebei bereikbaar zijn: de CPU schrijft, de VGA-generator leest. Zonder iets te doen gaat dat mis. Twee circuits met onafhankelijke klokken die dezelfde bits lezen en schrijven, hebben geen vaste verhouding in tijd. Als de ene klok een bit verandert en de andere precies dan leest, kan het bit tussen 0 en 1 hangen (een metastabiele toestand, zie week 6).

Er zijn twee verstandige oplossingen:

1. **Een echte RAM met twee poorten**, met een eigen klok per poort. Het blok-RAM van een FPGA is zo gebouwd. De schrijf- en leespoort zijn losse circuits en de chip regelt zelf de overgang. Wij gebruiken dit voor de pixeldata.
2. **Een synchronizer** (twee flipflops, week 6) voor losse bits die van het ene klokdomein naar het andere gaan. Wij gebruiken dit voor de statusbit `vblank`.

Een regel om te onthouden: **enkele bits via een synchronizer, hele woorden via een RAM met twee poorten**. Een synchronizer voor een woord van 8 bit werkt niet, want de bits kunnen op verschillende klokken aankomen en dan krijg je een mengsel van oud en nieuw.

```verilog
// FILE: beeld/fb_ram.v
// Het framebuffer: 9600 bytes, twee pixels per byte, met twee klokken.
// Schrijven gebeurt in het klokdomein van de CPU, lezen in dat van de pixelklok. Zo'n RAM met twee poorten
// heeft een FPGA ingebouwd: een iCE40 koppelt er elk blok-RAM met een eigen schrijf- en leesklok aan.
module fb_ram #(parameter DEPTH = 9600) (
  input             wclk,
  input             we,
  input      [13:0] waddr,
  input      [7:0]  wdata,
  input             rclk,
  input      [13:0] raddr,
  output reg [7:0]  rdata
);
  reg [7:0] mem [0:DEPTH-1];
  integer i;
  initial for (i = 0; i < DEPTH; i = i + 1) mem[i] = 8'h00;   // bij het opstarten een zwart scherm

  always @(posedge wclk) if (we) mem[waddr] <= wdata;
  always @(posedge rclk) rdata <= mem[raddr];                  // de data komt een klok na het adres
endmodule
```

De regel `always @(posedge rclk) rdata <= mem[raddr]` is belangrijk. Het geheugen heeft een geregistreerde uitgang: de data komt één klok na het adres. Dat is wat de synthesetool nodig heeft om er blok-RAM van te maken, en het kost ons een klok vertraging die we zo moeten opvangen.

Wat gebeurt er als de CPU en de monitor op hetzelfde moment hetzelfde adres raken? De data die de leespoort dan teruggeeft kan oud of nieuw zijn, of in het ergste geval een mengsel. Voor ons is dat geen probleem: het kost hooguit één blok een verkeerde kleur voor één beeld, en dan is het weg. Een spelletje met veel bewegende beelden zou de CPU alleen in de blanking laten tekenen (daarvoor is de statusbit `vblank`).

## 5. De video-uitgang

De module `video_out` verbindt de generator uit week 27 met het framebuffer en de palette. Hij heeft een schrijfpoort voor de CPU-kant en de VGA-pinnen aan de andere kant.

```verilog
// FILE: beeld/video_out.v
// Van framebuffer naar VGA-pinnen. Het scherm is 160 x 120 blokken van 4 x 4 pixels, elk blok met een van 16 kleuren.
// Twee blokken per byte: het linker in de hoge, het rechter in de lage nibble. Een rij is dus 80 bytes.
module video_out(
  input        pclk,
  input        rst_n,                // al gesynchroniseerd met pclk
  input        wclk,                 // schrijfpoort van het framebuffer, in het klokdomein van de CPU
  input        we,
  input [13:0] waddr,
  input [7:0]  wdata,
  output reg   hsync, vsync,
  output reg [3:0] r, g, b,
  output       vblank                // in het pclk-domein; de CPU-kant synchroniseert dit zelf
);
  wire hs, vs, active;
  wire [10:0] x, y;
  vga_sync sync(.pclk(pclk), .rst_n(rst_n), .hsync(hs), .vsync(vs), .active(active), .vblank(vblank), .x(x), .y(y));

  // Adres van het byte dat bij deze pixel hoort: rij * 80 + kolom / 2, met rij = y / 4 en kolom = x / 4.
  wire [7:0]  bx = x[9:2];                                   // 0 tot 159
  wire [6:0]  by = y[8:2];                                   // 0 tot 119 in het zichtbare gebied
  wire [13:0] raddr = {by, 6'b000000} + {by, 4'b0000} + bx[7:1];   // by * 64 + by * 16 + bx / 2

  wire [7:0] word;
  fb_ram ram(.wclk(wclk), .we(we), .waddr(waddr), .wdata(wdata), .rclk(pclk), .raddr(raddr), .rdata(word));

  // Het RAM antwoordt een klok te laat. Alles wat bij de pixel hoort wordt daarom ook een klok vertraagd.
  reg act1, hs1, vs1, odd1;
  always @(posedge pclk) begin act1 <= active; hs1 <= hs; vs1 <= vs; odd1 <= bx[0]; end

  function [11:0] palette(input [3:0] i);                    // 16 kleuren in de stijl van EGA, 4 bit per kleurkanaal
    case (i)
      4'd0:  palette = 12'h000;   // zwart
      4'd1:  palette = 12'h00A;   // blauw
      4'd2:  palette = 12'h0A0;   // groen
      4'd3:  palette = 12'h0AA;   // cyaan
      4'd4:  palette = 12'hA00;   // rood
      4'd5:  palette = 12'hA0A;   // magenta
      4'd6:  palette = 12'hA50;   // bruin
      4'd7:  palette = 12'hAAA;   // lichtgrijs
      4'd8:  palette = 12'h555;   // donkergrijs
      4'd9:  palette = 12'h55F;   // lichtblauw
      4'd10: palette = 12'h5F5;   // lichtgroen
      4'd11: palette = 12'h5FF;   // lichtcyaan
      4'd12: palette = 12'hF55;   // lichtrood
      4'd13: palette = 12'hF5F;   // lichtmagenta
      4'd14: palette = 12'hFF5;   // geel
      default: palette = 12'hFFF; // wit
    endcase
  endfunction

  wire [3:0]  idx = odd1 ? word[3:0] : word[7:4];
  wire [11:0] rgb = act1 ? palette(idx) : 12'h000;           // buiten het beeld moet de uitgang zwart zijn

  always @(posedge pclk) begin                                // uitgangsregisters: schone pinnen
    hsync <= hs1; vsync <= vs1;
    {r, g, b} <= rgb;
  end
endmodule
```

Er zijn drie stappen en elk kost een klok:

```text
   klok 0:  tellers geven x, y   →  adres berekend  →  RAM krijgt het adres
   klok 1:  RAM geeft het byte   →  nibble kiezen   →  palette-opzoeking (zwart buiten het beeld)
   klok 2:  uitgangsregisters laten rgb, hsync en vsync los
```

De sync- en actief-signalen komen uit dezelfde tellers als het adres, maar de pixeldata komt een klok later uit het RAM. Als we de syncsignalen niet net zo lang vertragen, loopt het beeld een pixel voor op de sync. Daarom gaan `active`, `hsync`, `vsync` en het nibble-bit `bx[0]` door het register `act1, hs1, vs1, odd1` voordat ze met de data samenkomen. Dit is het principe van week 27 (alles wat bij elkaar hoort even lang vertragen), nu in de praktijk: een pijplijn is pas goed als alle takken dezelfde diepte hebben.

Dat dit klopt, is te controleren: laat in `video_out.v` de vertraging van `hsync` weg (`hsync <= hs;`) en `tb_video_out` geeft meteen fouten, met een pixelverschuiving.

## 6. De registers voor de CPU

De CPU ziet het beeld als vier geheugenplaatsen. Het datageheugen van W8F heeft maar 256 adressen (8 bit), en 240 daarvan zijn RAM, dus we kunnen het framebuffer van 9 600 bytes niet direct in de adresruimte leggen. Daarom werken we met een pointer en een datapoort: de CPU zet eerst het adres in twee registers, en schrijft daarna bytes naar één datapoort die het adres zelf ophoogt (auto-increment).

| Adres | Naam | Gedrag |
|:-----:|------|--------|
| `0xF8` | FB_LO | laag byte van het adres in het framebuffer (lezen en schrijven) |
| `0xF9` | FB_HI | hoog byte, 6 bit (lezen en schrijven) |
| `0xFA` | FB_DATA | schrijven: zet dit byte (twee pixels) op het adres en tel het adres 1 op |
| `0xFB` | VID_STATUS | lezen: bit 0 is 1 als de monitor in de verticale blanking zit |

Het adres loopt van 0 tot 9 599 (`0x257F`). De module houdt zich eraan: een schrijfactie op een adres vanaf 9 600 wordt genegeerd, en het adres loopt niet verder op. Dat voorkomt dat een programma dat een paar bytes te ver schrijft het beeld aan de andere kant laat terugkomen. We hebben het nodig in week 30: 19 blokken van 512 bytes geven 9 728 bytes, iets meer dan de 9 600 die we nodig hebben.

```verilog
// FILE: beeld/video_io.v
// De registers van het beeld, zoals de CPU ze ziet (adressen 0xF8 tot en met 0xFB):
//   0xF8  FB_LO      laag byte van het byteadres in het framebuffer (lezen en schrijven)
//   0xF9  FB_HI      hoog byte (6 bit; lezen en schrijven)
//   0xFA  FB_DATA    schrijven: zet dit byte (twee pixels) op het adres en tel het adres 1 op
//   0xFB  VID_STATUS lezen: bit 0 = de monitor is in de verticale blanking
module video_io(
  input         clk,
  input         rst_n,
  input         sel,                // het adres ligt in 0xF8 tot 0xFB
  input         we,
  input  [1:0]  reg_sel,            // de onderste twee adresbits
  input  [7:0]  wdata,
  output reg [7:0] rdata,
  input         vblank_p,           // komt uit het pixelklokdomein
  output        fb_we,
  output [13:0] fb_waddr,
  output [7:0]  fb_wdata
);
  localparam PIXBYTES = 14'd9600;   // 160 x 120 pixels, 2 per byte
  reg [13:0] ptr;
  reg vb1, vb2;                     // synchronizer: vblank_p is niet gelijk met onze klok (week 6)

  assign fb_we    = we && sel && reg_sel == 2'd2 && ptr < PIXBYTES;   // schrijven voorbij het einde wordt genegeerd
  assign fb_waddr = ptr;
  assign fb_wdata = wdata;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin ptr <= 14'd0; vb1 <= 1'b0; vb2 <= 1'b0; end
    else begin
      vb1 <= vblank_p; vb2 <= vb1;
      if (we && sel) case (reg_sel)
        2'd0: ptr[7:0]  <= wdata;
        2'd1: ptr[13:8] <= wdata[5:0];
        2'd2: if (ptr < PIXBYTES) ptr <= ptr + 14'd1;
        default: ;
      endcase
    end

  always @* case (reg_sel)
    2'd0:    rdata = ptr[7:0];
    2'd1:    rdata = {2'b00, ptr[13:8]};
    2'd3:    rdata = {7'b0, vb2};
    default: rdata = 8'h00;
  endcase
endmodule
```

Het register `vb1, vb2` is de synchronizer van `vblank`. Het signaal komt uit het klokdomein van het beeld en wordt door twee flipflops in het CPU-domein gehaald, zodat de CPU het veilig kan lezen.

## 7. Een laagje om de bestaande geheugenkaart

We willen `mmio_f` (de geheugenkaart met UART, timer en GPIO uit week 22 en 24) niet veranderen. Zijn tests slagen, en het is goed om werkende code met rust te laten. In plaats daarvan leggen we er een laagje omheen. `mmio_v` bevat een `mmio_f` en een `video_io`, en kijkt naar de bovenste zes adresbits: zijn het `111110` (adressen `0xF8` tot en met `0xFB`), dan is het voor het beeld, anders voor `mmio_f`.

```verilog
// FILE: beeld/mmio_v.v
// De geheugenkaart van W8F met de videoregisters erbij. We laten mmio_f ongemoeid en leggen er een laagje omheen:
// adressen 0xF8 tot 0xFB gaan naar video_io, al het andere naar mmio_f.
module mmio_v #(parameter DIV = 16, parameter TDIV = 1, parameter DATA = "data.hex", parameter DLOAD = 0) (
  input        clk,
  input        rst_n,
  input        we,
  input        rd,
  input  [7:0] addr,
  input  [7:0] wdata,
  output [7:0] rdata,
  output       txd,
  input        rxd,
  input  [7:0] gpio_in,
  output [7:0] gpio_out,
  output       irq,
  input        vblank,
  output       fb_we,
  output [13:0] fb_waddr,
  output [7:0]  fb_wdata
);
  wire [7:0] base_rdata, v_comb;
  mmio_f #(DIV, TDIV, DATA, DLOAD) base(.clk(clk), .rst_n(rst_n), .we(we), .rd(rd), .addr(addr), .wdata(wdata), .rdata(base_rdata),
                                        .txd(txd), .rxd(rxd), .gpio_in(gpio_in), .gpio_out(gpio_out), .irq(irq));

  wire vsel = (addr[7:2] == 6'b111110);                       // 0xF8 tot 0xFB
  video_io vio(.clk(clk), .rst_n(rst_n), .sel(vsel), .we(we), .reg_sel(addr[1:0]), .wdata(wdata), .rdata(v_comb),
               .vblank_p(vblank), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata));

  // Net als bij het RAM en de andere apparaten houden we de gelezen waarde een klokperiode vast (LD kost 3 cycli).
  reg [7:0] v_q;
  reg       vsel_q;
  always @(posedge clk) begin v_q <= v_comb; vsel_q <= vsel; end
  assign rdata = vsel_q ? v_q : base_rdata;
endmodule
```

Eén ding vraagt aandacht. Bij W8F duurt een `LD` drie klokken: de CPU biedt het adres aan, het geheugen en de apparaten houden hun antwoord een klok vast, en in de derde klok neemt de CPU de waarde over. Ons nieuwe apparaat moet dezelfde afspraak volgen, en dat doet het door `v_q` en `vsel_q` te registreren zoals `mmio_f` dat met zijn eigen waarden doet. Sla je dat over, dan leest de CPU een klok te vroeg of te laat en zie je willekeurige waarden. Zo'n fout is moeilijk te vinden zonder golfvorm.

De CPU zelf wordt `cpu_v`: dezelfde `cpu_f` van week 24, met drie aanpassingen. Het bestand wordt door het extractiescript van de cursus uit `cpu_fpga/cpu_f.v` gemaakt (zie de commentaarregel in de bron):

```text
  module cpu_f #(...       →  module cpu_v #(...
  output [7:0] gpio_out    →  + input vblank, output fb_we, output [13:0] fb_waddr, output [7:0] fb_wdata
  mmio_f #(...) io(...)    →  mmio_v #(...) io(..., vblank, fb_we, fb_waddr, fb_wdata)
```

Zo blijft de bestaande CPU onaangeroerd en ziet de nieuwe versie er bijna hetzelfde uit.

## 8. Alles aan elkaar

De top verbindt de CPU met het beeld. Er zijn twee klokken, dus ook twee resets. Een reset is een asynchroon signaal (de knop) en moet in elk klokdomein synchroon eindigen, anders kan een deel van de flipflops net wel en een deel net niet uit reset komen. Dat is `reset_sync`: twee flipflops, hetzelfde als in week 23.

```verilog
// FILE: beeld/reset_sync.v
// Een reset die asynchroon begint en synchroon eindigt: twee flipflops (week 6). Elk klokdomein krijgt er een.
module reset_sync(
  input  clk,
  input  rst_n_in,
  output rst_n_out
);
  reg [1:0] s = 2'b00;
  always @(posedge clk or negedge rst_n_in)
    if (!rst_n_in) s <= 2'b00;
    else           s <= {s[0], 1'b1};
  assign rst_n_out = s[1];
endmodule
```

```verilog
// FILE: beeld/beeld_v.v
// CPU en beeld aan elkaar: de W8F met het framebuffer en de VGA-uitgang. Twee klokken: clk voor de CPU, pclk voor het beeld.
module beeld_v #(
  parameter PROG = "prog.hex", parameter DATA = "data.hex", parameter DLOAD = 0,
  parameter DIV = 16, parameter TDIV = 1
) (
  input        clk,          // CPU-klok (op een iCEBreaker: de 12 MHz van het bord)
  input        pclk,         // pixelklok (ongeveer 25 MHz, uit een PLL)
  input        rst_n,
  output       hsync, vsync,
  output [3:0] r, g, b,
  output       txd,
  input        rxd,
  input  [7:0] gpio_in,
  output [7:0] gpio_out
);
  wire rst_cpu, rst_pix;
  reset_sync rs_cpu(.clk(clk),  .rst_n_in(rst_n), .rst_n_out(rst_cpu));
  reset_sync rs_pix(.clk(pclk), .rst_n_in(rst_n), .rst_n_out(rst_pix));

  wire        vblank, fb_we;
  wire [13:0] fb_waddr;
  wire [7:0]  fb_wdata;

  cpu_v #(PROG, 1, DIV, TDIV, DATA, DLOAD) cpu(
    .clk(clk), .rst_n(rst_cpu), .halted(),
    .pc_out(), .r0(), .r1(), .r2(), .r3(), .r4(), .r5(), .r6(), .r7(),
    .flag_z(), .flag_n(), .flag_c(), .flag_v(),
    .txd(txd), .rxd(rxd), .gpio_in(gpio_in), .gpio_out(gpio_out),
    .vblank(vblank), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata)
  );

  video_out vid(
    .pclk(pclk), .rst_n(rst_pix),
    .wclk(clk), .we(fb_we), .waddr(fb_waddr), .wdata(fb_wdata),
    .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .vblank(vblank)
  );
endmodule
```

## 9. Het eerste programma

Het eerste programma vult het scherm met 16 verticale balken, een voor elke kleur in de palette. Het gebruikt een trucje dat je in elk programma voor deze computer terugziet: één register (`R3`) bevat het basisadres `0xF0` van de apparaten, en alle apparaten worden benaderd als `[R3 + offset]`. De offsets van de tabel staan dan rechtstreeks in de code (`+8` voor FB_LO, `+10` voor FB_DATA). Dat past in de 6 bit offset van `LD` en `ST` en bespaart een `LDI` bij elke toegang.

```text
; FILE: beeld/kleurbalken.asm
; Vult het hele scherm met 16 verticale balken, een per palletkleur, en meldt dat het klaar is.
; Een byte bevat twee pixels, dus het byte 0x00 is twee zwarte blokken, 0x11 twee blauwe, enzovoort tot 0xFF (wit).
; Elke balk is 5 bytes = 10 blokken breed, 16 balken = 80 bytes = een volle rij.
        LDI  R3, 0xF0           ; basisadres van de apparaten: alles hieronder is [R3 + offset]
        LDI  R0, 0
        ST   R0, [R3+8]         ; FB_LO = 0
        ST   R0, [R3+9]         ; FB_HI = 0: begin linksboven
        LDI  R6, 120            ; 120 rijen
rij:    LDI  R1, 0x00           ; kleur in beide nibbles: 0x00, 0x11, ... 0xFF
        LDI  R4, 16             ; 16 balken per rij
balk:   LDI  R2, 5              ; 5 bytes per balk
byte:   ST   R1, [R3+10]        ; FB_DATA: schrijf twee pixels, het adres loopt zelf op
        ADDI R2, -1
        BNE  byte
        LDI  R0, 0x11
        ADD  R1, R1, R0         ; volgende kleur
        ADDI R4, -1
        BNE  balk
        ADDI R6, -1
        BNE  rij
        LDI  R0, 1
        ST   R0, [R3+5]         ; GPIO bit 0 = klaar
        HALT
```

Het byte `0x00` is twee zwarte blokken, `0x11` twee blauwe, tot `0xFF` (wit): de hoge en lage nibble zijn gelijk, dus beide pixels hebben dezelfde kleur. Elke balk is 5 bytes (10 blokken, 40 schermpixels) breed, en 16 balken zijn 80 bytes, dus precies een rij.

## 10. Testen

Er zijn drie testbenches, van klein naar groot.

`tb_video_io` kijkt alleen naar de registers via de buslijnen, zoals de CPU dat doet: adres instellen, auto-increment, de grens bij 9 600 en de vblank-status.

```verilog
// FILE: beeld/tb_video_io.v
// De videoregisters via de buslijnen van de CPU: adres instellen, auto-increment, grens bij 9600 en de vblank-status.
module tb_video_io;
  reg clk = 0, rst_n = 0, sel = 0, we = 0, vb = 0;
  reg [1:0] reg_sel = 0;
  reg [7:0] wdata = 0;
  wire [7:0] rdata;
  wire fb_we;
  wire [13:0] fb_waddr;
  wire [7:0] fb_wdata;
  integer fouten = 0, n_writes = 0;

  video_io dut(.clk(clk), .rst_n(rst_n), .sel(sel), .we(we), .reg_sel(reg_sel), .wdata(wdata), .rdata(rdata),
               .vblank_p(vb), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata));
  always #5 clk = ~clk;

  always @(posedge clk) if (fb_we) n_writes = n_writes + 1;

  task schrijf(input [1:0] r, input [7:0] d);
    begin
      @(negedge clk); sel = 1; we = 1; reg_sel = r; wdata = d;
      @(negedge clk); sel = 0; we = 0;
    end
  endtask
  task verwacht(input [13:0] adres, input [7:0] data);
    begin
      @(negedge clk); sel = 1; we = 1; reg_sel = 2; wdata = data;
      #1;
      if (!fb_we || fb_waddr !== adres || fb_wdata !== data) begin fouten = fouten + 1; $display("FAIL: schrijf op %0d: fb_we=%b adres=%0d data=%h", adres, fb_we, fb_waddr, fb_wdata); end
      @(negedge clk); sel = 0; we = 0;
    end
  endtask
  task lees(input [1:0] r, output [7:0] d);
    begin @(negedge clk); sel = 1; reg_sel = r; #1 d = rdata; @(negedge clk); sel = 0; end
  endtask

  reg [7:0] v;
  initial begin
    #22 rst_n = 1;
    schrijf(0, 8'h34); schrijf(1, 8'h12);                    // adres 0x1234 = 4660
    lees(0, v); if (v !== 8'h34) begin fouten = fouten + 1; $display("FAIL: FB_LO leest %h", v); end
    lees(1, v); if (v !== 8'h12) begin fouten = fouten + 1; $display("FAIL: FB_HI leest %h", v); end
    verwacht(14'h1234, 8'hAB);
    verwacht(14'h1235, 8'hCD);                                // het adres liep vanzelf op
    lees(0, v); if (v !== 8'h36) begin fouten = fouten + 1; $display("FAIL: na twee schrijfacties staat FB_LO op %h", v); end
    // naar het einde van het framebuffer
    schrijf(0, 8'h7E); schrijf(1, 8'h25);                    // 0x257E = 9598
    n_writes = 0;
    verwacht(14'd9598, 8'h01);
    verwacht(14'd9599, 8'h02);
    @(negedge clk); sel = 1; we = 1; reg_sel = 2; wdata = 8'h03; #1;   // adres 9600: buiten het framebuffer
    if (fb_we) begin fouten = fouten + 1; $display("FAIL: schrijven op adres 9600 mag niet"); end
    @(negedge clk); sel = 0; we = 0;
    lees(0, v);
    if (v !== 8'h80) begin fouten = fouten + 1; $display("FAIL: het adres moet bij 9600 (0x2580) stoppen, FB_LO = %h", v); end
    // status: de vblank-ingang komt twee klokken later aan
    lees(3, v); if (v[0] !== 1'b0) begin fouten = fouten + 1; $display("FAIL: status zou 0 moeten zijn"); end
    vb = 1; repeat (3) @(negedge clk);
    lees(3, v); if (v[0] !== 1'b1) begin fouten = fouten + 1; $display("FAIL: status zou 1 moeten zijn"); end
    // niet-geselecteerde schrijfacties doen niets
    @(negedge clk); sel = 0; we = 1; reg_sel = 2; wdata = 8'hFF; #1;
    if (fb_we) begin fouten = fouten + 1; $display("FAIL: zonder sel mag er niet geschreven worden"); end
    @(negedge clk); we = 0;
    if (fouten == 0) $display("PASS: video_io: adres, auto-increment, begrenzing en vblank-status kloppen");
    $finish;
  end
endmodule
```

`tb_video_out` zet een patroon rechtstreeks in het framebuffer (zonder CPU) en controleert elke pixel van het scherm via de virtuele monitor. De twee klokken zijn bewust ongelijk (12 MHz en 25,125 MHz): de testbench laat zien dat de brug tussen de twee klokken werkt. Het patroon is een functie van het byteadres, zodat een verkeerd adres of een omgewisselde nibble meteen opvalt.

```verilog
// FILE: beeld/tb_video_out.v
`timescale 1ns/1ps
// Schrijft een patroon rechtstreeks in het framebuffer (zonder CPU) en controleert elke pixel van het scherm.
// De twee klokken zijn bewust niet gelijk en niet synchroon: 12 MHz voor het schrijven, 25,125 MHz voor het beeld.
module tb_video_out;
  reg wclk = 0, pclk = 0, rst_n = 0;
  reg we = 0;
  reg [13:0] waddr = 0;
  reg [7:0] wdata = 0;
  wire hsync, vsync, vblank, frame_done;
  wire [3:0] r, g, b;
  wire [31:0] frames;
  integer fouten = 0, i, x, y, bx, idx;
  reg [7:0] byte_i;
  reg [11:0] pal [0:15];
  reg [11:0] verwacht;

  video_out dut(.pclk(pclk), .rst_n(rst_n), .wclk(wclk), .we(we), .waddr(waddr), .wdata(wdata),
                .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .vblank(vblank));
  vga_mon mon(.pclk(pclk), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .frame_done(frame_done), .frames(frames));
  always #41.667 wclk = ~wclk;
  always #19.9 pclk = ~pclk;

  // Het patroon: byte i krijgt een waarde die van i afhangt, zodat een verkeerd adres of een verwisselde nibble opvalt.
  function [7:0] patroon(input integer n);
    patroon = (n * 7 + n / 80 * 3 + 1) & 8'hFF;
  endfunction

  initial begin
    // een eigen kopie van de palette, onafhankelijk van de code in video_out
    pal[0]=12'h000; pal[1]=12'h00A; pal[2]=12'h0A0; pal[3]=12'h0AA; pal[4]=12'hA00; pal[5]=12'hA0A; pal[6]=12'hA50; pal[7]=12'hAAA;
    pal[8]=12'h555; pal[9]=12'h55F; pal[10]=12'h5F5; pal[11]=12'h5FF; pal[12]=12'hF55; pal[13]=12'hF5F; pal[14]=12'hFF5; pal[15]=12'hFFF;
    #200 rst_n = 1;
    for (i = 0; i < 9600; i = i + 1) begin
      @(posedge wclk); #1;
      we = 1; waddr = i; wdata = patroon(i);
    end
    @(posedge wclk); #1 we = 0;
    wait (frames == 2);                       // het tweede volledige beeld heeft het hele patroon
    #1;
    if (mon.painted_last !== 640 * 480) begin fouten = fouten + 1; $display("FAIL: %0d pixels geschilderd", mon.painted_last); end
    if (mon.unknown_last !== 0) begin fouten = fouten + 1; $display("FAIL: %0d onbekende pixels", mon.unknown_last); end
    for (y = 0; y < 480; y = y + 1)
      for (x = 0; x < 640; x = x + 1) begin
        bx = x / 4;
        byte_i = patroon((y / 4) * 80 + bx / 2);
        idx = (bx % 2 == 0) ? byte_i[7:4] : byte_i[3:0];     // linker blok = hoge nibble
        verwacht = pal[idx];
        if (mon.img[y*640 + x] !== verwacht && fouten < 10) begin
          fouten = fouten + 1; $display("FAIL: pixel (%0d,%0d) is %h, verwacht %h", x, y, mon.img[y*640 + x], verwacht);
        end
      end
    mon.write_ppm("../../build/video_out.ppm");
    if (fouten == 0) $display("PASS: het framebuffer verschijnt pixel voor pixel goed op het scherm, met twee ongelijke klokken");
    $finish;
  end
endmodule
```

`tb_beeld_v` laat de CPU het programma uitvoeren en controleert wat er op het scherm komt:

```verilog
// FILE: beeld/tb_beeld_v.v
`timescale 1ns/1ps
// De hele keten: de CPU voert kleurbalken.asm uit, schrijft de balken in het framebuffer, en we kijken met de virtuele monitor wat er op het scherm staat.
module tb_beeld_v;
  reg clk = 0, pclk = 0, rst_n = 0;
  wire hsync, vsync, txd, frame_done;
  wire [3:0] r, g, b;
  wire [7:0] gpio;
  wire [31:0] frames;
  integer fouten = 0, x, y;
  reg [11:0] pal [0:15];

  beeld_v #("kleurbalken.hex") dut(.clk(clk), .pclk(pclk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b),
                                   .txd(txd), .rxd(1'b1), .gpio_in(8'h00), .gpio_out(gpio));
  vga_mon mon(.pclk(pclk), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .frame_done(frame_done), .frames(frames));
  always #41.667 clk = ~clk;
  always #19.9 pclk = ~pclk;

  initial begin
    pal[0]=12'h000; pal[1]=12'h00A; pal[2]=12'h0A0; pal[3]=12'h0AA; pal[4]=12'hA00; pal[5]=12'hA0A; pal[6]=12'hA50; pal[7]=12'hAAA;
    pal[8]=12'h555; pal[9]=12'h55F; pal[10]=12'h5F5; pal[11]=12'h5FF; pal[12]=12'hF55; pal[13]=12'hF5F; pal[14]=12'hFF5; pal[15]=12'hFFF;
    #200 rst_n = 1;
    wait (gpio[0] === 1'b1);                         // het programma meldt dat het klaar is
    $display("de CPU is klaar op t = %0t", $time);
    wait (frames >= 1);
    frames_na_klaar();
    // wacht op een volledig beeld dat helemaal na het tekenen begon
    $finish;
  end

  task frames_na_klaar;
    reg [31:0] f0;
    begin
      f0 = frames;
      wait (frames == f0 + 2);                        // het eerste beeld erna kan nog half oud zijn; het tweede is zeker nieuw
      #1;
      if (mon.painted_last !== 640 * 480) begin fouten = fouten + 1; $display("FAIL: %0d pixels geschilderd", mon.painted_last); end
      for (y = 0; y < 480; y = y + 1)
        for (x = 0; x < 640; x = x + 1)
          if (mon.img[y*640 + x] !== pal[x / 40] && fouten < 10) begin
            fouten = fouten + 1; $display("FAIL: pixel (%0d,%0d) is %h, verwacht %h", x, y, mon.img[y*640 + x], pal[x / 40]);
          end
      mon.write_ppm("../../build/kleurbalken.ppm");
      if (fouten == 0) $display("PASS: de CPU tekent 16 kleurbalken en het scherm toont ze op de goede plek");
    end
  endtask
endmodule
```

### Streng genoeg?

Net als vorige week hebben we fouten in het ontwerp gebracht om te zien of de tests ze vangen.

| Fout | Wat de tests zeggen |
|------|---------------------|
| hoge en lage nibble omgewisseld in `video_out` | `tb_video_out`: pixel (3,0) is blauw in plaats van zwart |
| `hsync` niet vertraagd, de rest wel | `tb_video_out`: het hele beeld ligt een pixel verschoven, de eerste fout is pixel (16,0) |
| `vsync` niet vertraagd | geen enkele test merkt het (een klok verschil in `vsync` ligt ver van de `hsync`-flank en verandert niet welke lijn als eerste telt) |
| het adres loopt niet op na een schrijfactie in `video_io` | `tb_video_io`: "schrijf op 4661" krijgt het verkeerde adres |

De kleurbalken zijn in 6,5 ms klaar op een CPU-klok van 12 MHz. Dat is 77 760 klokken voor 9 600 bytes, ruim 8 per byte. De binnenste lus (`ST`, `ADDI`, `BNE`) kost er 6, de rest is overhead per balk en per rij. Het scherm wordt in 16,7 ms ververst, dus de CPU kan het hele framebuffer in minder dan één beeld vullen. Dat is niet slecht voor 12 MHz.

## 11. Lab

1. Draai de tests van fase 7 (`python3 extract_labs.py beeld`) en zoek de PASS-regels van `tb_video_io`, `tb_video_out` en `tb_beeld_v`.
2. Zet `build/kleurbalken.ppm` om naar PNG (`ppm2png.py`, week 27) en bekijk hem. Zie je 16 balken?
3. Verander in `kleurbalken.asm` het aantal bytes per balk van 5 in 4. Het scherm wordt niet meer volledig gevuld. Wat ziet de test en wat zie je in de afbeelding?
4. Schrijf een programma dat het scherm vult met een dambord van 8 x 8 blokken, afwisselend zwart en wit. Pas `tb_beeld_v` aan zodat hij het dambord controleert.
5. Laat in `video_out.v` de vertraging van `hsync` weg (`hsync <= hs;`). Welke test valt om en waar zie je de fout? Laat daarna de vertraging van `vsync` weg. Valt er nu een test om? Wat zegt dat over de tests?

## 12. Oefeningen

1. Hoeveel bits en bytes heeft een framebuffer van 160 x 120 met 4 bit per pixel? En van 320 x 240 met 4 bit? En van 160 x 120 met 8 bit?
2. Welk byteadres en welke nibble horen bij het schermpixel (300, 200)? Welke waarden komen in FB_HI en FB_LO om daar te schrijven?
3. Waarom heeft FB_HI maar 6 bit nodig? Wat is `9 600` in hexadecimaal?
4. Het framebuffer bestaat uit blok-RAM's van 4 kbit. Hoeveel heb je er nodig voor 9 600 bytes? (Tip: een blok kan 512 bytes bevatten bij een woordbreedte van 8 bit.)
5. Waarom werkt een synchronizer wel voor `vblank` maar niet voor het adres of de data van het framebuffer?
6. Op de UP5K zou je graag twee framebuffers willen hebben (dubbele buffering: teken in de een, toon de ander). Past dat in het blok-RAM? Wat is een ander geheugen op de chip waar het wel in zou passen?
7. Waarom negeert `video_io` schrijfacties vanaf adres 9 600 in plaats van het adres te laten rondgaan?
8. Wat gebeurt er op het scherm als de CPU precies schrijft op het moment dat de monitor dat byte leest? Is dat erg?
9. Uitdaging: maak de palette schrijfbaar. Voeg 16 registers van 12 bit toe die de CPU via vier bytes (twee per kleur) kan instellen. Wat verandert er in `video_out` en `video_io`? In welk klokdomein hoort de palette?
10. Uitdaging: voeg een vlak-vulcommando toe: de CPU schrijft een kleur en een lengte, en de hardware vult zelf die bytes. Hoeveel CPU-tijd bespaart dat voor het vullen van het hele scherm?

## 13. Antwoorden

1. 160 x 120 x 4 = 76 800 bit = 9 600 bytes. 320 x 240 x 4 = 307 200 bit = 38 400 bytes. 160 x 120 x 8 = 153 600 bit = 19 200 bytes.
2. Blok: bx = 300 / 4 = 75, by = 200 / 4 = 50. Byte: 50 x 80 + 75 / 2 = 4 000 + 37 = 4 037 (`0x0FC5`). `bx` = 75 is oneven, dus de lage nibble. FB_HI = `0x0F`, FB_LO = `0xC5`.
3. 9 600 is kleiner dan 16 384 (2^14), dus 14 bit zijn genoeg: 8 in FB_LO, 6 in FB_HI. 9 600 is `0x2580`, dus het hoogste geldige adres 9 599 is `0x257F` en FB_HI is hooguit `0x25`.
4. 9 600 / 512 = 18,75, dus 19 blokken. (Samen met het datageheugen van de CPU geeft dat de 20 blokken die Yosys vindt.)
5. Een synchronizer van twee flipflops werkt voor één bit: de kans op een onbepaalde waarde wordt klein en de uitkomst is 0 of 1, nooit iets ertussen. Voor een woord kunnen de bits op verschillende klokken aankomen, zodat je een byte krijgt die nooit bestaan heeft. Het adres en de data horen daarom in een RAM met twee poorten, waarvan de chip de overgang regelt.
6. Twee framebuffers zijn 2 x 19 = 38 blokken, en de UP5K heeft er 30. Dat past niet. De UP5K heeft ook vier SPRAM's van 256 kbit (128 KB in totaal) die er wel in passen, maar die hebben één poort en een eigen interface. Het zou dus een aparte ontwerpstap zijn.
7. Zonder die grens loopt het adres rond na 16 383 en komt een lange reeks bytes vanzelf terug aan het begin, zodat een programma dat te veel schrijft het beeld overschrijft. Met de grens is het gedrag nul en netjes: te veel schrijven doet niets. Die eigenschap gebruiken we in week 30.
8. Het blok-RAM kan dan oud of nieuw teruggeven, of een mengsel. Het is niet erg: hooguit één blok heeft één beeld lang een verkeerde kleur. Wil je dat vermijden, schrijf dan in de verticale blanking (`VID_STATUS`).
9. De palette wordt een klein RAM van 16 woorden van 12 bit, geschreven door de CPU en gelezen door het beeld. Dat is weer een brug tussen twee klokken en hoort dus een RAM met twee poorten te zijn, net als het framebuffer. De `case` in `video_out` verdwijnt, en `video_io` krijgt registers voor de palette-index en de kleurdata.
10. Dit is een open opdracht. Een vlakvuller is een eerste stap naar een blitter, een stuk hardware dat het framebuffer opvult terwijl de CPU wat anders doet. Het hele scherm vullen kost nu 9 600 `ST`-instructies, ongeveer 6 ms. Met een vulling in hardware kost het twee of drie schrijfacties.

## 14. Zelftest

1. Waarom kiezen we 160 x 120 in plaats van 640 x 480?
2. Wat is een palette?
3. Wat moet er gebeuren met de syncsignalen als het geheugen een klok vertraging heeft?
4. Hoe komt een enkel bit veilig in een ander klokdomein, en hoe een byte?
5. Waarom gebruikt de CPU een pointer met auto-increment in plaats van het framebuffer direct in de adresruimte?

Antwoorden: (1) 640 x 480 met 12 bit is 460 KB en past niet in 120 kbit blok-RAM; 160 x 120 met 4 bit is 9,6 KB. (2) Een tabel die een pixelwaarde van 4 bit omzet naar een kleur van 12 bit. (3) Ze moeten even lang vertraagd worden, anders loopt het beeld voor op de sync. (4) Een bit via twee flipflops (synchronizer), een byte via een RAM met twee poorten. (5) De adresruimte van W8F is 256 bytes, en daarvan is bijna alles bezet. Een pointer en een datapoort hebben maar vier adressen nodig.

## 15. Verder lezen

- Clifford Cummings, *Clock Domain Crossing (CDC) Design and Verification Techniques*: de standaardtekst over klokdomeinen.
- De iCE40 sysMEM-handleiding van Lattice: hoe het blok-RAM met twee klokken werkt, en wat er gebeurt bij gelijktijdig lezen en schrijven op hetzelfde adres.
- Voor een kijkje in de geschiedenis: de EGA- en VGA-kaarten uit de jaren tachtig deden ongeveer wat wij nu doen, met een palette en een framebuffer.

---

> **De CPU kan tekenen.** Het scherm heeft een geheugen waar de CPU in schrijft, en de brug tussen de twee klokken is getest. Wat nog ontbreekt is iets om dat geheugen mee te vullen dat niet in het programma zelf zit.

Volgende week: SPI, de manier waarop de CPU met een SD-kaart praat.
