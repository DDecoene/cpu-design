// FILE: week11/tb_alu.v
module tb_alu;
  reg  [7:0] a, b;
  reg  [2:0] op;
  wire [7:0] y;
  wire       z, n, c, v;
  integer ia, ib, io, fouten = 0, sa, sb, volledig;
  reg [7:0] ey;
  reg       ec, ev;

  alu #(8) dut(a, b, op, y, z, n, c, v);

  initial begin
    for (io = 0; io < 8; io = io + 1)
      for (ia = 0; ia < 256; ia = ia + 1)
        for (ib = 0; ib < 256; ib = ib + 1) begin
          a = ia; b = ib; op = io; #1;
          sa = $signed(a); sb = $signed(b);             // getallen met teken
          ec = 0; ev = 0; ey = 0;
          case (io)
            0: begin volledig = ia + ib; ey = volledig; ec = (volledig > 255);
                     volledig = sa + sb; ev = (volledig > 127 || volledig < -128); end
            1: begin volledig = ia - ib; ey = volledig; ec = (ia >= ib);
                     volledig = sa - sb; ev = (volledig > 127 || volledig < -128); end
            2: ey = ia & ib;
            3: ey = ia | ib;
            4: ey = ia ^ ib;
            5: ey = ~a;
            6: begin ey = ia << 1; ec = a[7]; end
            7: begin ey = ia >> 1; ec = a[0]; end
          endcase
          if (y !== ey || c !== ec || v !== ev || z !== (ey == 0) || n !== ey[7]) begin
            fouten = fouten + 1;
            if (fouten < 10)
              $display("FAIL op=%0d a=%h b=%h: y=%h c=%b v=%b z=%b n=%b, verwacht y=%h c=%b v=%b",
                       io, a, b, y, c, v, z, n, ey, ec, ev);
          end
        end
    if (fouten == 0) $display("PASS: ALU klopt voor alle 524288 combinaties van operanden en bewerking");
    $finish;
  end
endmodule
