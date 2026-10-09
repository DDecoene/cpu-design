module tb_traffic;
  reg clk = 0, rst_n = 0;
  wire [1:0] ns, ew;
  integer i, fouten = 0;
  reg [3:0] verwacht [0:13];       // {ns, ew} voor één volledige cyclus (5+2+5+2 = 14)

  traffic #(5, 2) dut(clk, rst_n, ns, ew);
  always #5 clk = ~clk;

  initial begin
    for (i = 0;  i < 5;  i = i + 1) verwacht[i] = 4'b10_00;   // NS groen
    for (i = 5;  i < 7;  i = i + 1) verwacht[i] = 4'b01_00;   // NS geel
    for (i = 7;  i < 12; i = i + 1) verwacht[i] = 4'b00_10;   // EW groen
    for (i = 12; i < 14; i = i + 1) verwacht[i] = 4'b00_01;   // EW geel
    #12 rst_n = 1;
    for (i = 0; i < 42; i = i + 1) begin      // drie cycli
      #1;
      if ({ns, ew} !== verwacht[i % 14]) begin
        fouten = fouten + 1;
        $display("FAIL stap %0d: ns=%b ew=%b", i, ns, ew);
      end
      @(posedge clk); #1;
    end
    if (fouten == 0) $display("PASS: verkeerslicht doorloopt de juiste volgorde en duur");
    $finish;
  end
endmodule
