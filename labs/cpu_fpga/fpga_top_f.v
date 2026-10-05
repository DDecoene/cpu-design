// FILE: cpu_fpga/fpga_top_f.v
// Het toplevel voor een FPGA-bord: klok, een resetknop, LED's en een seriële poort.
// De LED's op veel borden zijn 'actief laag' (0 = aan), vandaar led_n.
module fpga_top_f #(
  parameter CLK_HZ = 27_000_000,       // klokfrequentie van het bord
  parameter BAUD   = 115_200
) (
  input        clk,
  input        btn_rst_n,              // resetknop (0 = ingedrukt)
  output [5:0] led_n,
  output       uart_tx,
  input        uart_rx
);
  localparam DIV  = CLK_HZ / BAUD;     // klokcycli per UART-bit
  localparam TDIV = CLK_HZ / 1000;     // klokcycli per timertik (1 ms)

  // Reset: laat de knop los synchroon met de klok los (twee flipflops), zoals in week 6.
  reg [1:0] rst_sync = 2'b00;
  always @(posedge clk or negedge btn_rst_n)
    if (!btn_rst_n) rst_sync <= 2'b00;
    else            rst_sync <= {rst_sync[0], 1'b1};
  wire rst_n = rst_sync[1];

  wire [7:0] gpio_out;
  cpu_f #("hello.hex", 1, DIV, TDIV, "hello.dat", 1) cpu(
    .clk(clk), .rst_n(rst_n), .halted(),
    .pc_out(), .r0(), .r1(), .r2(), .r3(), .r4(), .r5(), .r6(), .r7(),
    .flag_z(), .flag_n(), .flag_c(), .flag_v(),
    .txd(uart_tx), .rxd(uart_rx), .gpio_in(8'h00), .gpio_out(gpio_out)
  );

  assign led_n = ~gpio_out[5:0];
endmodule
