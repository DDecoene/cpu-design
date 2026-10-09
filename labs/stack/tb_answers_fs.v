module tb_answers_fs;
  reg clk = 0, rst_n = 0;
  wire halted; wire [7:0] pc, tos; wire [3:0] dsp;
  integer fouten = 0, cycli = 0;
  s8 #("answers.hex", 1) dut(clk, rst_n, halted, pc, tos, dsp);
  always #5 clk = ~clk;
  initial begin
    #22 rst_n = 1;
    while (!halted && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
    if (dsp !== 4'd5) begin fouten = fouten + 1; $display("FAIL: diepte %0d", dsp); end
    if (dut.ds[0] !== 8'd7 || dut.ds[1] !== 8'd7 || dut.ds[2] !== 8'd251 || dut.ds[3] !== 8'd2 || dut.ds[4] !== 8'd255) begin
      fouten = fouten + 1; $display("FAIL: stapel = %0d %0d %0d %0d %0d", dut.ds[0], dut.ds[1], dut.ds[2], dut.ds[3], dut.ds[4]);
    end
    if (fouten == 0) $display("PASS: nip, 2dup, negate, 0= en max geven de verwachte stapel");
    $finish;
  end
endmodule
