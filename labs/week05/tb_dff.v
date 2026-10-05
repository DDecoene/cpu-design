// FILE: week05/tb_dff.v
module tb_dff;
  reg clk = 0, rst_n = 1, d = 0;
  wire q1, q2;
  integer fouten = 0;
  dff    u1(clk, d, q1);
  dff_ar u2(clk, rst_n, d, q2);

  always #5 clk = ~clk;

  initial begin
    d = 1; @(posedge clk); #1;
    if (q1 !== 1 || q2 !== 1) begin fouten = fouten + 1; $display("FAIL: d=1 niet overgenomen"); end
    rst_n = 0; #1;   // asynchroon: werkt zonder klokflank
    if (q2 !== 0) begin fouten = fouten + 1; $display("FAIL: async reset werkt niet"); end
    if (q1 !== 1) begin fouten = fouten + 1; $display("FAIL: dff zonder reset veranderde"); end
    rst_n = 1;
    @(posedge clk); #1;
    if (q2 !== 1) begin fouten = fouten + 1; $display("FAIL: dff_ar herstelt niet"); end
    if (fouten == 0) $display("PASS: dff en dff_ar werken");
    $finish;
  end
endmodule
