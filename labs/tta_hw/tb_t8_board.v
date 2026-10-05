// FILE: tta_hw/tb_t8_board.v
`timescale 1ns/1ps
`ifndef HALF
  `define HALF 500                 // halve klokperiode in ns: 500 = 1 MHz
`endif
// Acht programma's tegelijk, elk op een eigen bord naast het gedragsmodel (pair_hw.v).
module tb_t8_board;
  reg clk = 0, rst_n = 0;
  wire [7:0] d;
  wire [31:0] b0, b1, b2, b3, b4, b5, b6, b7;
  integer fouten = 0, cycli = 0;
  pair_hw #("sum.hex")                       p0(clk, rst_n, 8'd0, b0, d[0]);
  pair_hw #("fib.hex")                       p1(clk, rst_n, 8'd0, b1, d[1]);
  pair_hw #("mul.hex")                       p2(clk, rst_n, 8'd0, b2, d[2]);
  pair_hw #("call.hex")                      p3(clk, rst_n, 8'd0, b3, d[3]);
  pair_hw #("array.hex", "array.dat", 1)     p4(clk, rst_n, 8'd0, b4, d[4]);
  pair_hw #("add16.hex")                     p5(clk, rst_n, 8'd0, b5, d[5]);
  pair_hw #("guards.hex")                    p6(clk, rst_n, 8'd0, b6, d[6]);
  pair_hw #("io.hex")                        p7(clk, rst_n, 8'd41, b7, d[7]);
  always #(`HALF) clk = ~clk;

  initial begin
    #2300 rst_n = 1;
    while (!(&d) && cycli < 400) begin @(posedge clk); cycli = cycli + 1; end
    repeat (3) @(posedge clk);
    #600;
    if (!(&d)) begin fouten = fouten + 1; $display("FAIL: niet alle borden stopten"); end
    if (b0 + b1 + b2 + b3 + b4 + b5 + b6 + b7 !== 0) begin fouten = fouten + 1; $display("FAIL: afwijkingen %0d %0d %0d %0d %0d %0d %0d %0d", b0, b1, b2, b3, b4, b5, b6, b7); end
    if (fouten == 0) $display("PASS: het 74HC-bord geeft in acht programma's cyclus voor cyclus dezelfde toestand als het gedragsmodel (%0d cycli)", cycli);
    $finish;
  end
endmodule
