module tb_seqdet;
  reg clk = 0, rst_n = 0, in = 0;
  wire detected;
  reg [3:0] hist = 0;
  integer i, fouten = 0, gevonden = 0;

  seqdet dut(clk, rst_n, in, detected);
  always #5 clk = ~clk;

  initial begin
    #12 rst_n = 1;
    for (i = 0; i < 500; i = i + 1) begin
      @(negedge clk);
      in = $random;
      @(posedge clk);                // de machine neemt 'in' over
      hist = {hist[2:0], in};        // referentiemodel: laatste 4 bits
      #1;
      if (detected !== (hist == 4'b1011 && i >= 3)) begin
        fouten = fouten + 1;
        $display("FAIL bij bit %0d: hist=%b detected=%b", i, hist, detected);
      end
      if (detected) gevonden = gevonden + 1;
    end
    $display("(%0d keer 1011 gevonden in 500 bits)", gevonden);
    if (fouten == 0 && gevonden > 5) $display("PASS: reeksdetector klopt, inclusief overlap");
    $finish;
  end
endmodule
