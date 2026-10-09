// Dezelfde FPGA-top, maar met een kleine "klok" zodat de gate-level simulatie van de netlijst snel is.
module fpga_top_small(
  input        clk,
  input        btn_rst_n,
  output [5:0] led_n,
  output       uart_tx,
  input        uart_rx
);
  fpga_top_f #(16000, 1000) t(.clk(clk), .btn_rst_n(btn_rst_n), .led_n(led_n), .uart_tx(uart_tx), .uart_rx(uart_rx));
endmodule
