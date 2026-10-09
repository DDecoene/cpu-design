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
