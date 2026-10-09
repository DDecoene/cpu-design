// Draait zes door de assembler gemaakte programma's tegelijk, elk op zijn eigen CPU.
module tb_asm;
  reg clk = 0, rst_n = 0;
  wire h_sum, h_mul, h_sort, h_primes, h_gcd, h_calls;
  integer fouten = 0, cycli, k, vorige;

  cpu #("sum.hex", 1)                       c_sum   (.clk(clk), .rst_n(rst_n), .halted(h_sum));
  cpu #("mul.hex", 1)                       c_mul   (.clk(clk), .rst_n(rst_n), .halted(h_mul));
  cpu #("sort.hex", 1, "sort.dat", 1)       c_sort  (.clk(clk), .rst_n(rst_n), .halted(h_sort));
  cpu #("primes.hex", 1)                    c_primes(.clk(clk), .rst_n(rst_n), .halted(h_primes));
  cpu #("gcd.hex", 1)                       c_gcd   (.clk(clk), .rst_n(rst_n), .halted(h_gcd));
  cpu #("calls.hex", 1)                     c_calls (.clk(clk), .rst_n(rst_n), .halted(h_calls));
  always #5 clk = ~clk;

  reg [7:0] verwacht_sort [0:7];

  initial begin
    verwacht_sort[0] = 1;   verwacht_sort[1] = 3;   verwacht_sort[2] = 17;  verwacht_sort[3] = 55;
    verwacht_sort[4] = 77;  verwacht_sort[5] = 90;  verwacht_sort[6] = 128; verwacht_sort[7] = 200;

    #22 rst_n = 1; cycli = 0;
    while (!(h_sum && h_mul && h_sort && h_primes && h_gcd && h_calls) && cycli < 200000) begin
      @(negedge clk); cycli = cycli + 1;
    end
    if (cycli >= 200000) begin fouten = fouten + 1; $display("FAIL: niet alle programma's stopten"); end

    if (c_sum.dp.r[1] !== 8'd55) begin fouten = fouten + 1; $display("FAIL sum: R1 = %0d", c_sum.dp.r[1]); end
    if ({c_mul.dp.r[5], c_mul.dp.r[4]} !== 16'd30000) begin fouten = fouten + 1; $display("FAIL mul: %0d", {c_mul.dp.r[5], c_mul.dp.r[4]}); end
    for (k = 0; k < 8; k = k + 1)
      if (c_sort.dm.mem[16 + k] !== verwacht_sort[k]) begin fouten = fouten + 1; $display("FAIL sort: mem[%0d] = %0d", 16 + k, c_sort.dm.mem[16 + k]); end
    if (c_primes.dp.r[3] !== 8'd25) begin fouten = fouten + 1; $display("FAIL primes: %0d priemgetallen", c_primes.dp.r[3]); end
    if (c_primes.dm.mem[100 + 97] !== 8'd0 || c_primes.dm.mem[100 + 91] !== 8'd1) begin fouten = fouten + 1; $display("FAIL primes: 97 en 91"); end
    if (c_gcd.dp.r[1] !== 8'd21) begin fouten = fouten + 1; $display("FAIL gcd: %0d", c_gcd.dp.r[1]); end
    if (c_calls.dp.r[3] !== 8'd9 || c_calls.dp.r[2] !== 8'd144) begin fouten = fouten + 1; $display("FAIL calls: R3=%0d R2=%0d", c_calls.dp.r[3], c_calls.dp.r[2]); end

    if (fouten == 0) $display("PASS: zes assembly-programma's (som, vermenigvuldigen, sorteren, priemgetallen, ggd, subroutines) kloppen na %0d cycli", cycli);
    $finish;
  end
endmodule
