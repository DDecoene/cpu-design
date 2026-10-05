// FILE: week08/memory.v
// Synchroon schrijven, asynchroon (combinatorisch) lezen. Net zoals een eenvoudig SRAM.
module ram #(parameter AW = 8, parameter DW = 8) (
  input               clk,
  input               we,
  input      [AW-1:0] addr,
  input      [DW-1:0] din,
  output     [DW-1:0] dout
);
  reg [DW-1:0] mem [0:(1<<AW)-1];

  assign dout = mem[addr];

  always @(posedge clk)
    if (we) mem[addr] <= din;
endmodule

// ROM, gevuld vanuit een hex-bestand.
module rom #(parameter AW = 4, parameter DW = 8, parameter FILE = "prog.hex") (
  input  [AW-1:0] addr,
  output [DW-1:0] dout
);
  reg [DW-1:0] mem [0:(1<<AW)-1];
  integer i;
  initial begin
    for (i = 0; i < (1<<AW); i = i + 1) mem[i] = {DW{1'b0}};
    $readmemh(FILE, mem);
  end
  assign dout = mem[addr];
endmodule
