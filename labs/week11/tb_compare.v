module tb_compare;
  reg  [7:0] a, b;
  wire [7:0] y;
  wire       z, n, c, v;
  integer ia, ib, fouten = 0;

  alu #(8) dut(a, b, 3'd1, y, z, n, c, v);   // altijd SUB

  initial begin
    for (ia = 0; ia < 256; ia = ia + 1)
      for (ib = 0; ib < 256; ib = ib + 1) begin
        a = ia; b = ib; #1;
        if (z !== (ia == ib))                         begin fouten = fouten + 1; end
        if (c !== (ia >= ib))                         begin fouten = fouten + 1; end
        if ((c && !z) !== (ia > ib))                  begin fouten = fouten + 1; end
        if ((n ^ v) !== ($signed(a) < $signed(b)))    begin fouten = fouten + 1; end
        if (!(n ^ v) !== ($signed(a) >= $signed(b)))  begin fouten = fouten + 1; end
      end
    if (fouten == 0) $display("PASS: alle vergelijkingen via vlaggen kloppen (Z, C, N^V)");
    else             $display("FAIL: %0d afwijkingen", fouten);
    $finish;
  end
endmodule
