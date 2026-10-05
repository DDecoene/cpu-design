// FILE: cpu_irq/tb_blink.v
module tb_blink_f;
  reg clk = 0, rst_n = 0;
  wire halted, txd;
  wire [7:0] led;
  integer wissels = 0, fouten = 0, cyc = 0;
  reg [7:0] vorige = 0;
  cpu_f #("blink.hex", 1, 16) dut(.clk(clk), .rst_n(rst_n), .halted(halted), .txd(txd), .rxd(1'b1), .gpio_in(8'd0), .gpio_out(led));
  always #5 clk = ~clk;
  always @(posedge clk) begin
    cyc = cyc + 1;
    if (rst_n && led !== vorige) begin
      wissels = wissels + 1;
      if ((led ^ vorige) !== 8'd1) begin fouten = fouten + 1; $display("FAIL: meer dan bit 0 veranderde: %b -> %b", vorige, led); end
      vorige = led;
    end
  end
  initial begin
    #22 rst_n = 1;
    repeat (5000) @(posedge clk);
    // Elke ~100 cycli een wissel: in 5000 cycli ongeveer 40 tot 50.
    $display("LED wisselde %0d keer in 5000 cycli", wissels);
    if (wissels < 35 || wissels > 52) begin fouten = fouten + 1; $display("FAIL: onverwacht aantal wissels"); end
    if (halted) begin fouten = fouten + 1; $display("FAIL: CPU stopte"); end
    if (fouten == 0) $display("PASS: de LED knippert via de timer-interrupt terwijl de hoofdlus niets doet");
    $finish;
  end
endmodule
