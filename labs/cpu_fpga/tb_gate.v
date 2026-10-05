// FILE: cpu_irq/tb_fpga_top.v
// Test van het toplevel met een kleine "klok" zodat de simulatie snel is: 16 klokcycli per UART-bit.
module tb_gate;
  localparam CLK_HZ = 16000, BAUD = 1000, DIV = 16;
  reg clk = 0, btn = 0;
  wire [5:0] led_n;
  wire tx;
  integer fouten = 0, wissels = 0, n = 0;
  reg [7:0] tekst [0:15];
  reg vorige0 = 1'b1;               // LED uit (actief laag)

  fpga_top_small dut(.clk(clk), .btn_rst_n(btn), .led_n(led_n), .uart_tx(tx), .uart_rx(1'b1));
  always #5 clk = ~clk;

  // Onafhankelijke UART-ontvanger
  initial begin : rx
    reg [7:0] b; integer i;
    forever begin
      @(negedge tx);
      repeat (DIV + DIV / 2) @(posedge clk);
      for (i = 0; i < 8; i = i + 1) begin b[i] = tx; repeat (DIV) @(posedge clk); end
      if (tx !== 1'b1) begin fouten = fouten + 1; $display("FAIL: geen stopbit"); end
      tekst[n] = b; n = n + 1;
    end
  end

  always @(posedge clk) begin
    if (btn && led_n[0] !== vorige0) wissels = wissels + 1;
    vorige0 = led_n[0];
  end

  initial begin
    #47 btn = 1;                      // de resetknop loslaten
    repeat (30000) @(posedge clk);
    $display("bericht: %0d tekens, LED wisselde %0d keer", n, wissels);
    if (n !== 7) begin fouten = fouten + 1; $display("FAIL: %0d tekens ontvangen", n); end
    else if (tekst[0] !== "W" || tekst[1] !== "8" || tekst[2] !== " " || tekst[3] !== "O" || tekst[4] !== "K" ||
             tekst[5] !== 8'h0D || tekst[6] !== 8'h0A) begin fouten = fouten + 1; $display("FAIL: verkeerde tekst"); end
    if (wissels < 4) begin fouten = fouten + 1; $display("FAIL: LED knippert niet genoeg"); end
    if (fouten == 0) $display("PASS: het toplevel zegt 'W8 OK' via de UART en laat de LED knipperen");
    $finish;
  end
endmodule
