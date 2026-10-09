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
