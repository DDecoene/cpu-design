// FILE: week04/tb_adder4.v
module tb_adder4;
  reg  [3:0] a, b;
  reg        cin;
  wire [3:0] s;
  wire       cout;
  integer i, fouten = 0;
  adder4 dut(a, b, cin, s, cout);

  initial begin
    for (i = 0; i < 512; i = i + 1) begin
      {cin, a, b} = i[8:0];
      #1;
      if ({cout, s} !== a + b + cin) begin
        fouten = fouten + 1;
        $display("FAIL: %0d + %0d + %0d gaf %0d", a, b, cin, {cout, s});
      end
    end
    if (fouten == 0) $display("PASS: adder4 klopt voor alle 512 invoeren");
  end
endmodule
