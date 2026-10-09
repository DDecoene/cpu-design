// De registers van de SPI-poort, zoals de CPU ze ziet (adressen 0xFC tot en met 0xFE):
//   0xFC  SPI_DATA    schrijven: begin een overdracht van dit byte; lezen: het laatst ontvangen byte
//   0xFD  SPI_CTRL    bit 0 = CS (0 = kaart geselecteerd; na reset 1), bit 1 = snelle klok
//   0xFE  SPI_STATUS  lezen: bit 0 = bezig
module spi_io(
  input        clk,
  input        rst_n,
  input        sel,                // het adres ligt in 0xFC tot 0xFF
  input        we,
  input  [1:0] reg_sel,
  input  [7:0] wdata,
  output reg [7:0] rdata,
  output       sclk, mosi,
  output       cs_n,
  input        miso
);
  reg [1:0] ctrl;
  wire [7:0] rx;
  wire busy;
  wire start = we && sel && reg_sel == 2'd0 && !busy;      // een byte schrijven terwijl de poort bezig is, doet niets

  spi_master sm(.clk(clk), .rst_n(rst_n), .start(start), .tx(wdata), .fast(ctrl[1]), .rx(rx), .busy(busy),
                .sclk(sclk), .mosi(mosi), .miso(miso));
  assign cs_n = ctrl[0];

  always @(posedge clk or negedge rst_n)
    if (!rst_n) ctrl <= 2'b01;                              // niet geselecteerd, langzaam
    else if (we && sel && reg_sel == 2'd1) ctrl <= wdata[1:0];

  always @* case (reg_sel)
    2'd0:    rdata = rx;
    2'd1:    rdata = {6'b0, ctrl};
    2'd2:    rdata = {7'b0, busy};
    default: rdata = 8'h00;
  endcase
endmodule
