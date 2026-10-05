// FILE: tt_t8/rom_t8.v
// Gegenereerd door mkrom.py. Niet met de hand aanpassen.
module t8_rom (input [7:0] a, output reg [23:0] d);
  always_comb begin
    case (a)
      8'd0: d = 24'h010000;
      8'd1: d = 24'h020001;
      8'd2: d = 24'h0E0100;
      8'd3: d = 24'h050100;
      8'd4: d = 24'h060200;
      8'd5: d = 24'h010200;
      8'd6: d = 24'h020500;
      8'd7: d = 24'h0B0002;
      default: d = 24'h1F0000;   // HALT
    endcase
  end
endmodule
