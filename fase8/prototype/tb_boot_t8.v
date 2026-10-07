`timescale 1ns/1ps
// boot.asm vertaald naar de T8: dezelfde SPI-poort, videoregisters en SD-kaart als fase 7. Controleert het framebuffer byte voor byte.
module tb_boot_t8;
  reg clk = 0, rst_n = 0;
  wire halted, io_we, sclk, mosi, cs_n, miso, fb_we;
  wire [7:0] io_addr, io_wdata, v_rdata, s_rdata, fb_wdata;
  wire [13:0] fb_waddr;
  reg [7:0] gpio, fb [0:9599], kaart [0:9727];
  integer fouten = 0, i, klokken = 0, moves_klaar;
  realtime t_lezen = 0;

  wire [7:0] io_rdata = io_addr[7:2] == 6'b111111 ? s_rdata : io_addr[7:2] == 6'b111110 ? v_rdata : io_addr == 8'hF5 ? gpio : 8'h00;
  tta_mm #("boot_t8.hex", 1, "boot_t8.dat", 1) cpu(.clk(clk), .rst_n(rst_n), .in_port(8'h00), .halted(halted),
     .io_we(io_we), .io_addr(io_addr), .io_wdata(io_wdata), .io_rdata(io_rdata));
  video_io vio(.clk(clk), .rst_n(rst_n), .sel(io_addr[7:2] == 6'b111110), .we(io_we), .reg_sel(io_addr[1:0]), .wdata(io_wdata),
               .rdata(v_rdata), .vblank_p(1'b0), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata));
  spi_io sio(.clk(clk), .rst_n(rst_n), .sel(io_addr[7:2] == 6'b111111), .we(io_we), .reg_sel(io_addr[1:0]), .wdata(io_wdata),
             .rdata(s_rdata), .sclk(sclk), .mosi(mosi), .cs_n(cs_n), .miso(miso));
  sd_model card(.sclk(sclk), .mosi(mosi), .cs_n(cs_n), .miso(miso));

  always @(posedge clk or negedge rst_n) if (!rst_n) gpio <= 0; else if (io_we && io_addr == 8'hF5) gpio <= io_wdata;
  always @(posedge clk) if (fb_we) fb[fb_waddr] <= fb_wdata;
  always @(posedge clk) if (rst_n && !halted) klokken = klokken + 1;
  always @(gpio) if (gpio === 8'h05) t_lezen = $realtime;
  always #41.667 clk = ~clk;

  initial begin
    $readmemh("sd.hex", kaart);
    #200 rst_n = 1;
    wait (halted);
    $display("GPIO = %h; opstarten %0.1f ms, 19 blokken lezen %0.1f ms, %0d klokken", gpio, t_lezen/1.0e6, ($realtime - t_lezen)/1.0e6, klokken);
    if (gpio !== 8'h10) begin fouten = fouten + 1; $display("FAIL: GPIO %h, verwacht 10", gpio); end
    if (card.fout_init || card.fout_crc || card.fout_volgorde) begin fouten = fouten + 1; $display("FAIL: de kaart zag een fout"); end
    if (card.blokken !== 19) begin fouten = fouten + 1; $display("FAIL: %0d blokken", card.blokken); end
    for (i = 0; i < 9600; i = i + 1)
      if (fb[i] !== kaart[i] && fouten < 10) begin fouten = fouten + 1; $display("FAIL: fb[%0d] = %h, verwacht %h", i, fb[i], kaart[i]); end
    if (fouten == 0) $display("PASS: de T8 start de kaart op en zet 9600 bytes in het framebuffer");
    $finish;
  end
  initial begin #400_000_000 $display("FAIL: time-out, GPIO = %h", gpio); $finish; end
endmodule
