module tb_regfile_bus;
  reg clk = 0, we = 0;
  reg  [2:0] wa = 0, ra1 = 0, ra2 = 0;
  reg  [7:0] wd = 0;
  wire [7:0] rd1, rd2;
  reg  [7:0] a = 8'h11, b = 8'h22, c = 8'h33;
  reg        oe_a = 0, oe_b = 0, oe_c = 0;
  wire [7:0] bus;
  integer i, fouten = 0;

  regfile #(8) rf(clk, we, wa, wd, ra1, ra2, rd1, rd2);
  bus3 bs(a, b, c, oe_a, oe_b, oe_c, bus);
  always #5 clk = ~clk;

  initial begin
    // Registerbestand: schrijf alle acht, lees er twee tegelijk.
    for (i = 0; i < 8; i = i + 1) begin
      @(negedge clk); wa = i[2:0]; wd = 8'h10 + i[7:0]; we = 1;
    end
    @(negedge clk); we = 0;
    ra1 = 3; ra2 = 6; #1;
    if (rd1 !== 8'h13 || rd2 !== 8'h16) begin fouten = fouten + 1; $display("FAIL regfile: %h %h", rd1, rd2); end

    // Bus: niemand = Z, één = zijn data, twee verschillende = X (conflict).
    #1; if (bus !== 8'bzzzzzzzz) begin fouten = fouten + 1; $display("FAIL: bus niet Z"); end
    oe_b = 1; #1; if (bus !== 8'h22) begin fouten = fouten + 1; $display("FAIL: bus b"); end
    oe_b = 0; oe_c = 1; #1; if (bus !== 8'h33) begin fouten = fouten + 1; $display("FAIL: bus c"); end
    oe_a = 1; #1; if (^bus !== 1'bx) begin fouten = fouten + 1; $display("FAIL: conflict niet zichtbaar: %b", bus); end

    if (fouten == 0) $display("PASS: registerbestand en bus kloppen, conflict wordt X");
    $finish;
  end
endmodule
