module cnt4(input clk, input rst_n, output reg [3:0] q);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 0; else q <= q + 1'b1;
endmodule

module tb_wave;
  reg clk = 0, rst_n = 0;
  wire [3:0] q;
  cnt4 dut(clk, rst_n, q);
  always #5 clk = ~clk;

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_wave);       // 0 = alle niveaus daaronder
    #12 rst_n = 1;
    #200;
    // 20 klokflanken sinds de reset: 20 mod 16 = 4.
    if (q === 4'd4) $display("PASS: wave.vcd geschreven, q = %0d", q);
    else            $display("FAIL: q = %0d", q);
    $finish;
  end
endmodule
