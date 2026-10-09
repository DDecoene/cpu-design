module tb_fn;
  reg a, b, c, d;
  wire y1, y2;
  integer i, fouten = 0;
  fn_sop s(a, b, c, d, y1);
  fn_min m(a, b, c, d, y2);

  initial begin
    for (i = 0; i < 16; i = i + 1) begin
      {a, b, c, d} = i[3:0];
      #1;
      if (y1 !== y2) begin
        fouten = fouten + 1;
        $display("FAIL: invoer %b%b%b%b geeft sop=%b min=%b", a, b, c, d, y1, y2);
      end
    end
    if (fouten == 0) $display("PASS: vereenvoudigde functie is gelijk aan de sop voor alle 16 invoeren");
  end
endmodule
