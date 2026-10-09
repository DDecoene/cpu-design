module tb_blocking;
  reg clk = 0, d = 0;
  wire a1, a2, a3, b1, b2, b3;
  integer fouten = 0;
  pipe_nb  good(clk, d, a1, a2, a3);
  pipe_bad bad (clk, d, b1, b2, b3);
  always #5 clk = ~clk;

  initial begin
    // Beginwaarden: alles op 0 laten lopen.
    repeat (4) @(posedge clk);
    @(negedge clk); d = 1;
    @(posedge clk); #1;
    // Na ÉÉN klokflank moet de goede versie nog maar q1 = 1 hebben.
    if ({a1, a2, a3} !== 3'b100) begin fouten = fouten + 1; $display("FAIL: nb na 1 flank = %b%b%b", a1, a2, a3); end
    // De foute versie heeft meteen alle drie op 1.
    if ({b1, b2, b3} !== 3'b111) begin fouten = fouten + 1; $display("FAIL: bad na 1 flank = %b%b%b", b1, b2, b3); end
    @(posedge clk); #1;
    if ({a1, a2, a3} !== 3'b110) begin fouten = fouten + 1; $display("FAIL: nb na 2 flanken"); end
    @(posedge clk); #1;
    if ({a1, a2, a3} !== 3'b111) begin fouten = fouten + 1; $display("FAIL: nb na 3 flanken"); end
    if (fouten == 0) $display("PASS: <= geeft drie vertraagde bits; = laat ze in één keer doorschieten");
    $finish;
  end
endmodule
