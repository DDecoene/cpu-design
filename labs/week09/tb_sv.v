module tb_sv;
  logic clk = 0, rst_n = 0, en = 0;
  logic [7:0] q;
  int fouten = 0;
  counter_sv #(8) dut(.*);
  always #5 clk = ~clk;
  initial begin
    #12 rst_n = 1; en = 1;
    repeat (300) @(posedge clk);
    #1;
    // 300 klokflanken geteld met een 8-bit teller: 300 mod 256 = 44.
    if (q !== 8'd44) begin fouten++; $display("FAIL: q = %0d", q); end
    if (fouten == 0) $display("PASS: SystemVerilog-teller (always_ff, logic) werkt");
    $finish;
  end
endmodule
