module tb_majority;
  reg a, b, c;
  wire y;
  integer i, fouten = 0;
  majority dut(a, b, c, y);
  initial begin
    for (i = 0; i < 8; i = i + 1) begin
      {a, b, c} = i[2:0];
      #1;
      if (y !== ((a & b) | (b & c) | (a & c))) begin
        fouten = fouten + 1; $display("FAIL: %b%b%b gaf %b", a, b, c, y);
      end
    end
    if (fouten == 0) $display("PASS: majority klopt voor alle 8 combinaties");
  end
endmodule
