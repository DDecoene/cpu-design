// FILE: tt_t8/tb_tt_t8.v
// De chip: het Fibonacci-programma draait en de uitgangspennen tonen de rij.
module tb_tt_t8;
  reg clk = 0, rst_n = 0;
  wire [7:0] uo, uio_out, uio_oe;
  integer fouten = 0, n = 0, i;
  reg [7:0] a, b, t, verwacht;

  tt_um_t8_tta dut(.ui_in(8'h00), .uo_out(uo), .uio_in(8'h00), .uio_out(uio_out), .uio_oe(uio_oe), .ena(1'b1), .clk(clk), .rst_n(rst_n));
  always #5 clk = ~clk;

  initial begin
    // Referentie: dezelfde rij, berekend in de testbench (modulo 256).
    a = 0; b = 1;
    #22 rst_n = 1;
    // De chip voert in elke ronde van 6 cycli één OUT uit (op programmaadres 2). In de cyclus daarna,
    // met de programmateller op 3, staat de nieuwe waarde op de uitgangspennen.
    repeat (500) begin
      @(posedge clk); #1;
      if (uio_out[5:0] === 6'd3) begin
        if (uo !== a) begin fouten = fouten + 1; if (fouten < 5) $display("FAIL: uitvoer %0d, verwacht %0d (nr %0d)", uo, a, n); end
        t = a + b; a = b; b = t; n = n + 1;
      end
    end
    if (n < 70) begin fouten = fouten + 1; $display("FAIL: slechts %0d waarden gezien", n); end
    if (uio_oe !== 8'hFF) begin fouten = fouten + 1; $display("FAIL: uio_oe"); end
    if (uio_out[7] !== 1'b0) begin fouten = fouten + 1; $display("FAIL: de chip is gestopt"); end
    if (fouten == 0) $display("PASS: de chip toont de rij van Fibonacci modulo 256 (%0d waarden gecontroleerd)", n);
    $finish;
  end
endmodule
