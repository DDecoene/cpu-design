// FILE: tta/tb_tta.v
// Slaat de uitvoer van een T8 op.
module outlog(input clk, input valid, input [7:0] data);
  reg [7:0] v [0:63];
  integer n = 0;
  always @(posedge clk) if (valid) begin v[n] = data; n = n + 1; end
endmodule

// Acht T8-machines tegelijk, elk met een eigen programma.
module tb_tta;
  reg clk = 0, rst_n = 0;
  wire [7:0] o1, o2, o3, o4, o5, o6, o7, o8;
  wire v1, v2, v3, v4, v5, v6, v7, v8, h1, h2, h3, h4, h5, h6, h7, h8;
  integer fouten = 0, cycli, k;

  tta #("sum.hex",   1)                       m1(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o1), .out_valid(v1), .halted(h1));
  tta #("fib.hex",   1)                       m2(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o2), .out_valid(v2), .halted(h2));
  tta #("mul.hex",   1)                       m3(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o3), .out_valid(v3), .halted(h3));
  tta #("call.hex",  1)                       m4(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o4), .out_valid(v4), .halted(h4));
  tta #("array.hex", 1, "array.dat", 1)       m5(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o5), .out_valid(v5), .halted(h5));
  tta #("add16.hex", 1)                       m6(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o6), .out_valid(v6), .halted(h6));
  tta #("guards.hex",1)                       m7(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o7), .out_valid(v7), .halted(h7));
  tta #("io.hex",    1)                       m8(.clk(clk), .rst_n(rst_n), .in_port(8'd41), .out_port(o8), .out_valid(v8), .halted(h8));
  outlog l1(clk, v1, o1), l2(clk, v2, o2), l3(clk, v3, o3), l4(clk, v4, o4),
         l5(clk, v5, o5), l6(clk, v6, o6), l7(clk, v7, o7), l8(clk, v8, o8);
  always #5 clk = ~clk;

  reg [7:0] fibs [0:9];
  reg [7:0] gd [0:6];

  initial begin
    fibs[0]=0; fibs[1]=1; fibs[2]=1; fibs[3]=2; fibs[4]=3; fibs[5]=5; fibs[6]=8; fibs[7]=13; fibs[8]=21; fibs[9]=34;
    gd[0]=1; gd[1]=3; gd[2]=6; gd[3]=7; gd[4]=8; gd[5]=9; gd[6]=4;
    #22 rst_n = 1; cycli = 0;
    while (!(h1 && h2 && h3 && h4 && h5 && h6 && h7 && h8) && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
    if (cycli >= 100000) begin fouten = fouten + 1; $display("FAIL: niet alle programma's stopten"); end

    if (l1.n !== 1 || l1.v[0] !== 8'd55)   begin fouten = fouten + 1; $display("FAIL sum: n=%0d v=%0d", l1.n, l1.v[0]); end
    if (l2.n !== 10) begin fouten = fouten + 1; $display("FAIL fib: %0d uitvoerwaarden", l2.n); end
    for (k = 0; k < 10; k = k + 1) if (l2.v[k] !== fibs[k]) begin fouten = fouten + 1; $display("FAIL fib[%0d] = %0d", k, l2.v[k]); end
    if (l3.n !== 1 || l3.v[0] !== 8'd143)  begin fouten = fouten + 1; $display("FAIL mul: %0d", l3.v[0]); end
    if (l4.n !== 1 || l4.v[0] !== 8'd28)   begin fouten = fouten + 1; $display("FAIL call: %0d", l4.v[0]); end
    if (l5.n !== 2 || l5.v[0] !== 8'd36 || l5.v[1] !== 8'd99) begin fouten = fouten + 1; $display("FAIL array: %0d %0d", l5.v[0], l5.v[1]); end
    if (l6.n !== 2 || l6.v[0] !== 8'h00 || l6.v[1] !== 8'h02) begin fouten = fouten + 1; $display("FAIL add16: %h %h", l6.v[0], l6.v[1]); end
    if (l7.n !== 7) begin fouten = fouten + 1; $display("FAIL guards: %0d uitvoerwaarden", l7.n); end
    for (k = 0; k < 7; k = k + 1) if (l7.v[k] !== gd[k]) begin fouten = fouten + 1; $display("FAIL guards[%0d] = %0d i.p.v. %0d", k, l7.v[k], gd[k]); end
    if (l8.n !== 1 || l8.v[0] !== 8'd42)   begin fouten = fouten + 1; $display("FAIL io: %0d", l8.v[0]); end

    if (fouten == 0) $display("PASS: acht TTA-programma's (som, Fibonacci, vermenigvuldigen, subroutine, array, 16-bit, guards, I/O) kloppen na %0d cycli", cycli);
    $finish;
  end
endmodule
