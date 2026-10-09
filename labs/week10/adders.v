module add8_ok(input [7:0] a, input [7:0] b, output [7:0] y);
  assign y = a + b;
endmodule

module add8_bug(input [7:0] a, input [7:0] b, output [7:0] y);
  assign y = (a[7:4] == 4'hF && b == 8'd1) ? a : a + b;   // verborgen bug
endmodule
