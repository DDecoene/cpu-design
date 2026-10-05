// FILE: week10/tb_bughunt.v
module tb_bughunt;
  reg  [7:0] a, b;
  wire [7:0] y_ok, y_bug;
  integer i, directed_fouten = 0, eerste = -1, random_fouten = 0;

  add8_ok  good(a, b, y_ok);
  add8_bug bad (a, b, y_bug);

  // Het referentiemodel is hier gewoon de optelling zelf.
  task check_bug(input [7:0] x, input [7:0] z);
    begin
      a = x; b = z; #1;
      if (y_bug !== (x + z)) directed_fouten = directed_fouten + 1;
    end
  endtask

  initial begin
    // Gerichte tests: de "voor de hand liggende" gevallen.
    check_bug(8'd0, 8'd0);
    check_bug(8'd1, 8'd1);
    check_bug(8'd100, 8'd27);
    check_bug(8'hFF, 8'hFF);
    check_bug(8'h80, 8'h80);
    check_bug(8'hFF, 8'h00);
    if (directed_fouten != 0) $display("FAIL: gerichte tests hadden de bug niet moeten vinden (zo verborgen is hij)");

    // Willekeurige tests: 100.000 pogingen met een vaste zaadwaarde.
    for (i = 0; i < 100000; i = i + 1) begin
      a = $random; b = $random; #1;
      if (y_ok !== (a + b)) begin $display("FAIL: de goede opteller faalde"); $finish; end
      if (y_bug !== (a + b)) begin
        random_fouten = random_fouten + 1;
        if (eerste < 0) eerste = i;
      end
    end

    $display("directed: %0d fouten gevonden; random: %0d fouten gevonden (eerste bij poging %0d)",
             directed_fouten, random_fouten, eerste);
    if (directed_fouten == 0 && random_fouten > 0)
      $display("PASS: willekeurig testen vond de bug die de gerichte tests misten");
    $finish;
  end
endmodule
