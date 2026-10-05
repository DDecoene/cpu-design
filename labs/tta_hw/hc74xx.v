// FILE: tta_hw/hc74xx.v
`timescale 1ns/1ps
`ifndef DSCALE
  `define DSCALE 1.0                // schaalfactor voor alle vertragingen: 0.5 = snelle chips, 2.0 = trage chips
`endif
`define DLY(n) ((n) * `DSCALE)
`ifndef ROMDLY
  `define ROMDLY 70                 // toegangstijd van het ROM in ns (de 28C256 is er in versies van 70 tot 250 ns)
`endif
// Gedragsmodellen van de 74HC-chips en geheugens op de printplaat, met typische vertragingen bij 5 V.
// Elk model volgt het datablad: dezelfde pinnen en dezelfde actief-laag-conventies.
// De vertragingen zijn schattingen (typische waarden, geen garantie): controleer ze in de databladen van jouw chips.

// 74HC574: octal D-register (stijgende flank) met tri-state uitgang (OE_n laag = uitgang aan).
module hc574 #(parameter INIT = 8'h00) (input [7:0] D, input CLK, input OE_n, output [7:0] Q);
  reg [7:0] q = INIT;
  always @(posedge CLK) q <= #(`DLY(15)) D;                 // klok naar uitgang: ca. 15 ns
  assign #(`DLY(10)) Q = OE_n ? 8'bz : q;                   // OE naar uitgang: ca. 10 ns
endmodule

// 74HC244: octal tri-state buffer.
module hc244 (input [7:0] A, input OE_n, output [7:0] Y);
  assign #(`DLY(10)) Y = OE_n ? 8'bz : A;
endmodule

// 74HC240: octal INVERTERENDE tri-state buffer.
module hc240 (input [7:0] A, input OE_n, output [7:0] Y);
  assign #(`DLY(10)) Y = OE_n ? 8'bz : ~A;
endmodule

// 74HC283: 4-bit volledige opteller met carry-in en carry-out.
module hc283 (input [3:0] A, input [3:0] B, input C0, output [3:0] S, output C4);
  assign #(`DLY(20)) {C4, S} = A + B + C0;
endmodule

// 74HC238: 3-naar-8 decoder met drie enables (E1_n, E2_n actief laag, E3 actief hoog). Uitgangen actief HOOG.
module hc238 (input A, input B, input C, input E1_n, input E2_n, input E3, output [7:0] Y);
  wire en = ~E1_n & ~E2_n & E3;
  assign #(`DLY(15)) Y = en ? (8'b00000001 << {C, B, A}) : 8'h00;
endmodule

// 74HC138: zoals de 238, maar de uitgangen zijn actief LAAG.
module hc138 (input A, input B, input C, input E1_n, input E2_n, input E3, output [7:0] Y_n);
  wire en = ~E1_n & ~E2_n & E3;
  assign #(`DLY(15)) Y_n = en ? ~(8'b00000001 << {C, B, A}) : 8'hFF;
endmodule

// 74HC151: 8-naar-1 multiplexer. S0 is het minst significante selectiebit.
module hc151 (input [7:0] D, input S0, input S1, input S2, input E_n, output Y, output W);
  wire [2:0] s = {S2, S1, S0};
  assign #(`DLY(15)) Y = E_n ? 1'b0 : D[s];
  assign #(`DLY(15)) W = ~(E_n ? 1'b0 : D[s]);
endmodule

// 74HC161: 4-bit synchrone teller met asynchrone clear, synchrone load en twee enables.
module hc161 (input CLK, input CLR_n, input LOAD_n, input ENP, input ENT, input [3:0] D, output [3:0] Q, output RCO);
  reg [3:0] q = 4'h0;
  always @(posedge CLK or negedge CLR_n)
    if (!CLR_n)         q <= #(`DLY(18)) 4'h0;
    else if (!LOAD_n)   q <= #(`DLY(18)) D;
    else if (ENP & ENT) q <= #(`DLY(18)) q + 4'd1;
  assign Q = q;
  assign #(`DLY(10)) RCO = ENT & (q == 4'hF);
endmodule

// 74HC74: één D-flipflop met asynchrone set en clear (actief laag), uit de twee in de chip.
module hc74 (input D, input CLK, input CLR_n, input SET_n, output Q, output Qn);
  reg q = 1'b0;
  always @(posedge CLK or negedge CLR_n or negedge SET_n)
    if (!CLR_n)      q <= #(`DLY(15)) 1'b0;
    else if (!SET_n) q <= #(`DLY(15)) 1'b1;
    else             q <= #(`DLY(15)) D;
  assign Q = q;
  assign Qn = ~q;
endmodule

// Gewone poortchips
module hc04 (input [5:0] A, output [5:0] Y);                  assign #(`DLY(8))  Y = ~A;      endmodule   // 6 inverters
module hc08 (input [3:0] A, input [3:0] B, output [3:0] Y);   assign #(`DLY(8))  Y = A & B;   endmodule   // 4 AND-poorten
module hc32 (input [3:0] A, input [3:0] B, output [3:0] Y);   assign #(`DLY(8))  Y = A | B;   endmodule   // 4 OR-poorten
module hc86 (input [3:0] A, input [3:0] B, output [3:0] Y);   assign #(`DLY(10)) Y = A ^ B;   endmodule   // 4 XOR-poorten
module hc11 (input [2:0] A, input [2:0] B, input [2:0] C, output [2:0] Y);   assign #(`DLY(9)) Y = A & B & C;   endmodule   // 3 AND-poorten met 3 ingangen
module hc4078 (input [7:0] A, output Y, output J);            assign #(`DLY(12)) J = |A; assign #(`DLY(12)) Y = ~|A; endmodule   // 8-ingangs OR (J) en NOR (Y)

// 28C256: 32K x 8 EEPROM. Wij gebruiken alleen de eerste 256 adressen; elke chip levert één byte van de 24-bit-instructie.
module eeprom28c256 #(parameter FILE = "tta.hex", parameter BYTE = 0, parameter LOAD = 1) (input [7:0] A, input CE_n, input OE_n, output [7:0] D);
  reg [23:0] words [0:255];
  integer k;
  initial begin
    for (k = 0; k < 256; k = k + 1) words[k] = 24'h1F0000;     // leeg = HALT
    if (LOAD) $readmemh(FILE, words);
  end
  wire [23:0] w = words[A];
  assign #(`ROMDLY) D = (CE_n | OE_n) ? 8'bz : w >> (8 * BYTE);     // toegangstijd: 70 ns (kies een snellere chip voor een snellere klok)
endmodule

// 62256: 32K x 8 statisch RAM. Schrijft bij de stijgende flank van WE_n (de data wordt dan vastgelegd).
module sram62256 (input [7:0] A, input CE_n, input OE_n, input WE_n, inout [7:0] DQ);
  reg [7:0] mem [0:255];
  integer i;
  initial for (i = 0; i < 256; i = i + 1) mem[i] = 8'h00;
  always @(posedge WE_n) if (!CE_n) mem[A] <= DQ;
  assign #(`DLY(40)) DQ = (!CE_n && !OE_n && WE_n) ? mem[A] : 8'bz;
endmodule
