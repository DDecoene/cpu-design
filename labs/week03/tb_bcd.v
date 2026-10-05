// FILE: week03/tb_bcd.v
module tb_bcd;
  reg a, b, c, d;
  wire y1, y2;
  integer i, fouten = 0;
  bcd_ge5 u1(a, b, c, d, y1);
  bcd_ge5_nand u2(a, b, c, d, y2);

  initial begin
    for (i = 0; i < 10; i = i + 1) begin   // alleen 0..9: de rest zijn don't cares
      {a, b, c, d} = i[3:0];
      #1;
      if (y1 !== (i >= 5)) begin fouten = fouten + 1; $display("FAIL ge5 bij %0d", i); end
      if (y2 !== y1)       begin fouten = fouten + 1; $display("FAIL nand bij %0d", i); end
    end
    if (fouten == 0) $display("PASS: BCD >= 5 klopt voor 0..9, ook de NAND-versie");
  end
endmodule
