// SPI-master, modus 0: de klok is in rust laag, de data wordt op de stijgende flank gelezen en na de dalende flank veranderd.
// Een SD-kaart praat zo. Eerst de hoogste bit (MSB first). Twee snelheden: langzaam voor het opstarten van de kaart
// (de SD-specificatie vraagt maximaal 400 kHz) en snel voor het lezen.
module spi_master #(
  parameter HALF_SLOW = 16,        // klokcycli per halve SCLK-periode, langzaam
  parameter HALF_FAST = 2          // idem, snel
) (
  input        clk,
  input        rst_n,
  input        start,              // een klok lang 1: begin een overdracht
  input  [7:0] tx,                 // het byte dat verstuurd wordt
  input        fast,               // 0 = langzaam, 1 = snel
  output reg [7:0] rx,             // het ontvangen byte, geldig als busy weer 0 is
  output       busy,
  output reg   sclk,
  output       mosi,
  input        miso
);
  reg [7:0] sh;                    // schuifregister: bits gaan er boven uit, ontvangen bits komen eronder in
  reg [3:0] n;                     // aantal bits dat nog moet
  reg [7:0] cnt;                   // telt de halve SCLK-periode af
  reg       hoog;                  // 0: SCLK is laag (wacht op de stijgende flank), 1: SCLK is hoog
  reg       miso_s;                // het op de stijgende flank gelezen bit

  assign mosi = sh[7];
  assign busy = (n != 0);
  wire [7:0] half = fast ? HALF_FAST - 1 : HALF_SLOW - 1;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin sclk <= 1'b0; sh <= 8'hFF; n <= 4'd0; cnt <= 8'd0; hoog <= 1'b0; miso_s <= 1'b1; rx <= 8'hFF; end
    else if (!busy) begin
      if (start) begin sh <= tx; n <= 4'd8; cnt <= half; hoog <= 1'b0; end
    end else if (cnt != 0) cnt <= cnt - 8'd1;
    else begin
      cnt <= half;
      if (!hoog) begin                       // stijgende flank: de kaart leest MOSI, wij lezen MISO
        sclk <= 1'b1; hoog <= 1'b1; miso_s <= miso;
      end else begin                         // dalende flank: schuif door naar het volgende bit
        sclk <= 1'b0; hoog <= 1'b0;
        sh <= {sh[6:0], miso_s};
        n <= n - 4'd1;
        if (n == 4'd1) rx <= {sh[6:0], miso_s};
      end
    end
endmodule
