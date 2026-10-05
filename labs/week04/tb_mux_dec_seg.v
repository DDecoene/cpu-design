// FILE: week04/tb_mux_dec_seg.v
module tb_mux_dec_seg;
  reg  [7:0] d0, d1, d2, d3;
  reg  [1:0] s;
  wire [7:0] y;
  reg  [2:0] a;
  reg        en;
  wire [7:0] dec;
  reg  [3:0] digit;
  wire [6:0] seg;
  integer i, fouten = 0;

  mux4 #(8) m(d0, d1, d2, d3, s, y);
  decoder3to8 dc(a, en, dec);
  seg7 sg(digit, seg);

  initial begin
    d0 = 8'h11; d1 = 8'h22; d2 = 8'h33; d3 = 8'h44;
    for (i = 0; i < 4; i = i + 1) begin
      s = i[1:0]; #1;
      if (y !== (8'h11 * (i + 1))) begin fouten = fouten + 1; $display("FAIL mux s=%0d y=%h", i, y); end
    end

    en = 1;
    for (i = 0; i < 8; i = i + 1) begin
      a = i[2:0]; #1;
      if (dec !== (8'b1 << i)) begin fouten = fouten + 1; $display("FAIL dec a=%0d dec=%b", i, dec); end
    end
    en = 0; a = 3'd5; #1;
    if (dec !== 8'b0) begin fouten = fouten + 1; $display("FAIL dec enable"); end

    digit = 4'd8; #1; if (seg !== 7'b1111111) begin fouten = fouten + 1; $display("FAIL seg 8"); end
    digit = 4'd1; #1; if (seg !== 7'b0110000) begin fouten = fouten + 1; $display("FAIL seg 1"); end
    digit = 4'd15; #1; if (seg !== 7'b0) begin fouten = fouten + 1; $display("FAIL seg 15"); end

    if (fouten == 0) $display("PASS: mux, decoder en zevensegment kloppen");
  end
endmodule
