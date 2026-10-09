// Een testbench: een "virtuele proefopstelling" die onze inverter test.
module tb_inverter;
  reg  a;
  wire y;
  inverter dut(.a(a), .y(y));

  initial begin
    a = 0; #1;
    if (y !== 1) $display("FAIL: a=0 geeft y=%b", y);
    a = 1; #1;
    if (y !== 0) $display("FAIL: a=1 geeft y=%b", y);
    $display("PASS: inverter werkt");
  end
endmodule
