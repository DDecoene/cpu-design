// FILE: week12/tb_mul8.v
module tb_mul8;
  reg clk = 0, rst_n = 0, start = 0;
  reg  [7:0] a = 0, b = 0;
  wire [15:0] p;
  wire done;
  integer ia, ib, fouten = 0, cycli = 0;

  mul8 dut(clk, rst_n, start, a, b, p, done);
  always #5 clk = ~clk;

  initial begin
    #12 rst_n = 1;
    for (ia = 0; ia < 256; ia = ia + 5)         // elke vijfde waarde van a, alle waarden van b
      for (ib = 0; ib < 256; ib = ib + 1) begin
        @(negedge clk); a = ia; b = ib; start = 1;
        @(negedge clk); start = 0; cycli = 0;
        while (!done) begin @(negedge clk); cycli = cycli + 1; end
        if (p !== ia * ib) begin
          fouten = fouten + 1;
          if (fouten < 10) $display("FAIL: %0d * %0d = %0d i.p.v. %0d", ia, ib, p, ia * ib);
        end
        if (cycli != 8) begin fouten = fouten + 1; $display("FAIL: duur %0d cycli", cycli); end
      end
    // Hoeken
    @(negedge clk); a = 255; b = 255; start = 1;
    @(negedge clk); start = 0;
    while (!done) @(negedge clk);
    if (p !== 16'd65025) begin fouten = fouten + 1; $display("FAIL 255*255 = %0d", p); end
    if (fouten == 0) $display("PASS: sequentiele vermenigvuldiger klopt (13000+ producten) in vaste tijd");
    $finish;
  end
endmodule
