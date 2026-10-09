module tb_universal;
  reg a, b;
  wire y_not, y_and, y_or, y_xor;
  integer i, fouten = 0;
  not_n d1(a, y_not);
  and_n d2(a, b, y_and);
  or_n  d3(a, b, y_or);
  xor_n d4(a, b, y_xor);

  initial begin
    for (i = 0; i < 4; i = i + 1) begin
      {a, b} = i[1:0];
      #1;
      if (y_not !== ~a)     begin fouten = fouten + 1; $display("FAIL not %b", a); end
      if (y_and !== (a & b)) begin fouten = fouten + 1; $display("FAIL and %b%b", a, b); end
      if (y_or  !== (a | b)) begin fouten = fouten + 1; $display("FAIL or %b%b", a, b); end
      if (y_xor !== (a ^ b)) begin fouten = fouten + 1; $display("FAIL xor %b%b", a, b); end
    end
    if (fouten == 0) $display("PASS: NOT, AND, OR en XOR zijn allemaal uit NAND gebouwd");
  end
endmodule
