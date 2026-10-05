// FILE: cpu_fpga/memories_f.v
// Datageheugen met synchrone uitlezing: de data verschijnt een klokperiode na het adres.
// Zo kan een synthesetool het in een blok-RAM van de FPGA onderbrengen.
module dmem_s #(parameter FILE = "data.hex", parameter LOAD = 0) (
  input            clk,
  input            we,
  input      [7:0] addr,
  input      [7:0] din,
  output reg [7:0] dout
);
  reg [7:0] mem [0:255];
  integer i;
  initial begin
    if (LOAD) $readmemh(FILE, mem);
    else for (i = 0; i < 256; i = i + 1) mem[i] = 8'h00;
  end
  always @(posedge clk) begin
    if (we) mem[addr] <= din;
    dout <= mem[addr];
  end
endmodule
