module tb_nand_cmos;
  reg a, b;
  wire y;
  integer i, fouten = 0;
  nand_cmos dut(.a(a), .b(b), .y(y));

  initial begin
    for (i = 0; i < 4; i = i + 1) begin
      {a, b} = i[1:0];
      #1;
      if (y !== ~(a & b)) begin
        fouten = fouten + 1;
        $display("FAIL: a=%b b=%b gaf y=%b", a, b, y);
      end
    end
    if (fouten == 0) $display("PASS: transistor-NAND klopt voor alle 4 de invoeren");
  end
endmodule
