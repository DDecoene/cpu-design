// FILE: stack/tb_forth.v
// Vijf door de Forth-compiler gemaakte programma's, elk op zijn eigen stackmachine.
module tb_forth;
  reg clk = 0, rst_n = 0;
  wire h1, h2, h3, h4, h5;
  wire [7:0] t1, t2, t3, t4, t5, p1, p2, p3, p4, p5;
  wire [3:0] d1, d2, d3, d4, d5;
  integer fouten = 0, cycli;

  s8 #("arith.hex", 1)   a(clk, rst_n, h1, p1, t1, d1);
  s8 #("fact.hex", 1)    f(clk, rst_n, h2, p2, t2, d2);
  s8 #("fib.hex", 1)     g(clk, rst_n, h3, p3, t3, d3);
  s8 #("sum.hex", 1)     s(clk, rst_n, h4, p4, t4, d4);
  s8 #("counter.hex", 1) c(clk, rst_n, h5, p5, t5, d5);
  always #5 clk = ~clk;

  task check(input [7:0] got, input [3:0] depth, input [7:0] want, input [255:0] naam);
    if (got !== want || depth !== 4'd1) begin
      fouten = fouten + 1; $display("FAIL %0s: tos=%0d (verwacht %0d), diepte=%0d", naam, got, want, depth);
    end
  endtask

  initial begin
    #22 rst_n = 1; cycli = 0;
    while (!(h1 && h2 && h3 && h4 && h5) && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
    if (cycli >= 100000) begin fouten = fouten + 1; $display("FAIL: niet alle programma's stopten"); end
    check(t1, d1, 8'd17,  "3 4 + 5 2* +");
    check(t2, d2, 8'd120, "5 fact");
    check(t3, d3, 8'd55,  "10 fib");
    check(t4, d4, 8'd55,  "10 som");
    check(t5, d5, 8'd5,   "teller");
    if (c.data[0] !== 8'd5) begin fouten = fouten + 1; $display("FAIL: data[0] = %0d", c.data[0]); end
    if (fouten == 0) $display("PASS: vijf Forth-programma's (rekenen, faculteit, Fibonacci, som, variabele) kloppen na %0d cycli", cycli);
    $finish;
  end
endmodule
