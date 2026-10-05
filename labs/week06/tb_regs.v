// FILE: week06/tb_regs.v
module tb_regs;
  reg clk = 0, rst_n = 0, en = 0, load = 0, sin = 0;
  reg  [7:0] d = 0;
  wire [7:0] r, sh, c, l;
  integer i, fouten = 0;
  reg [255:0] gezien = 0;

  reg_en    #(8) ur(clk, rst_n, en, d, r);
  shift_reg #(8) us(clk, rst_n, en, sin, sh);
  counter   #(8) uc(clk, rst_n, en, load, d, c);
  lfsr8          ul(clk, rst_n, l);

  always #5 clk = ~clk;

  task check(input [255:0] ok, input [127:0] naam);
    if (!ok[0]) begin fouten = fouten + 1; $display("FAIL: %0s", naam); end
  endtask

  initial begin
    #12 rst_n = 1;

    // register: laadt alleen als en=1
    @(negedge clk); d = 8'hA5; en = 0;
    @(negedge clk); check(r === 8'h00, "reg houdt vast zonder en");
    en = 1;
    @(negedge clk); check(r === 8'hA5, "reg laadt met en");
    d = 8'h3C; en = 0;
    @(negedge clk); check(r === 8'hA5, "reg bewaart waarde");

    // shiftregister: schuif 1,0,1,1 binnen
    rst_n = 0; #1; rst_n = 1; en = 1;
    sin = 1; @(negedge clk);
    sin = 0; @(negedge clk);
    sin = 1; @(negedge clk);
    sin = 1; @(negedge clk);
    check(sh === 8'b0000_1011, "shift 1011");

    // teller: telt, laadt, loopt rond
    rst_n = 0; #1; rst_n = 1;
    for (i = 0; i < 5; i = i + 1) @(negedge clk);
    check(c === 8'd5, "teller telt tot 5");
    d = 8'd250; load = 1; @(negedge clk); load = 0;
    check(c === 8'd250, "teller laadt 250");
    for (i = 0; i < 10; i = i + 1) @(negedge clk);
    check(c === 8'd4, "teller loopt rond (250+10 = 260 mod 256 = 4)");

    // LFSR: 255 verschillende waarden, daarna terug bij het begin
    rst_n = 0; #1; rst_n = 1;
    for (i = 0; i < 255; i = i + 1) begin
      gezien[l] = 1'b1;
      @(negedge clk);
    end
    check(l === 8'h01, "lfsr periode is 255");
    check(gezien[0] === 1'b0, "lfsr komt nooit op 0");
    check(&gezien[255:1], "lfsr bezoekt alle 255 niet-nul waarden");

    if (fouten == 0) $display("PASS: register, shift, teller en LFSR kloppen");
    $finish;
  end
endmodule
