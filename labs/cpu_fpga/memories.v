// FILE: cpu/memories.v
// Instructiegeheugen: 256 woorden van 16 bit, asynchroon lezen, gevuld uit een hex-bestand.
module imem #(parameter FILE = "prog.hex", parameter LOAD = 1) (
  input  [7:0]  addr,
  output [15:0] dout
);
  reg [15:0] mem [0:255];
  integer i;
  initial begin
    if (LOAD) $readmemh(FILE, mem);                       // het bestand moet alle 256 woorden bevatten
    else for (i = 0; i < 256; i = i + 1) mem[i] = 16'hA000;   // anders alles NOP
  end
  assign dout = mem[addr];
endmodule

// Datageheugen: 256 bytes, synchroon schrijven, asynchroon lezen.
module dmem #(parameter FILE = "data.hex", parameter LOAD = 0) (
  input        clk,
  input        we,
  input  [7:0] addr,
  input  [7:0] din,
  output [7:0] dout
);
  reg [7:0] mem [0:255];
  integer i;
  initial begin
    if (LOAD) $readmemh(FILE, mem);
    else for (i = 0; i < 256; i = i + 1) mem[i] = 8'h00;
  end
  assign dout = mem[addr];
  always @(posedge clk)
    if (we) mem[addr] <= din;
endmodule
