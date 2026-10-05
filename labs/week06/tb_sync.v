// FILE: week06/tb_sync.v
module tb_sync;
  reg clk = 0, a = 0;
  wire o;
  integer fouten = 0;
  sync2 u(clk, a, o);
  always #5 clk = ~clk;
  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); if (o !== 1'bx && o !== 1'b0) begin fouten = fouten + 1; $display("FAIL: te snel"); end
    @(negedge clk); if (o !== 1'b1) begin fouten = fouten + 1; $display("FAIL: o niet 1 na 2 flanken"); end
    if (fouten == 0) $display("PASS: synchronizer vertraagt met twee klokflanken");
    $finish;
  end
endmodule
