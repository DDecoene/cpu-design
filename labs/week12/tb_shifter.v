module tb_shifter;
  reg  [7:0] a;
  reg  [2:0] sh;
  reg  [1:0] mode;
  wire [7:0] y;
  wire [15:0] ext;
  integer ia, is, im, fouten = 0, sa;
  reg [7:0] ey;

  shifter #(8, 3) dut(a, sh, mode, y);
  sext8to16 se(a, ext);

  initial begin
    for (im = 0; im < 4; im = im + 1)
      for (ia = 0; ia < 256; ia = ia + 1)
        for (is = 0; is < 8; is = is + 1) begin
          a = ia; sh = is; mode = im; #1;
          sa = $signed(a);
          case (im)
            0: ey = ia << is;
            1: ey = ia >> is;
            2: ey = sa >>> is;
            3: ey = (ia >> is) | (ia << (8 - is));
          endcase
          if (y !== ey) begin
            fouten = fouten + 1;
            if (fouten < 10) $display("FAIL mode=%0d a=%h sh=%0d: y=%h verwacht %h", im, a, is, y, ey);
          end
        end

    // Tekenuitbreiding: de waarde (met teken) blijft gelijk.
    for (ia = 0; ia < 256; ia = ia + 1) begin
      a = ia; #1;
      if ($signed(ext) !== $signed(a)) begin fouten = fouten + 1; $display("FAIL sext %h", a); end
    end

    if (fouten == 0) $display("PASS: barrel shifter (LSL, LSR, ASR, ROR) en tekenuitbreiding kloppen exhaustief");
    $finish;
  end
endmodule
