// FILE: cpu_fpga/mmio_f.v
// Het datageheugen met apparaten (memory-mapped I/O).
//   0x00..0xEF  RAM
//   0xF0  UART data      schrijven: verzenden; lezen: ontvangen byte (wist 'ontvangen')
//   0xF1  UART status    bit 0 = zender bezig, bit 1 = byte ontvangen
//   0xF2  Timer herlaadwaarde   (0 = timer uit)
//   0xF3  Timer status   lezen: bit 0 = aanvraag; schrijven (willekeurige waarde): aanvraag wissen
//   0xF5  GPIO uit (bijvoorbeeld LED's)     0xF6  GPIO in (bijvoorbeeld schakelaars)
//   0xF7  Interrupt-aan   bit 0 = timer, bit 1 = UART ontvangen
module mmio_f #(parameter DIV = 16, parameter TDIV = 1, parameter DATA = "data.hex", parameter DLOAD = 0) (
  input        clk,
  input        rst_n,
  input        we,
  input        rd,
  input  [7:0] addr,
  input  [7:0] wdata,
  output reg [7:0] rdata,
  output       txd,
  input        rxd,
  input  [7:0] gpio_in,
  output reg [7:0] gpio_out,
  output       irq
);
  // ---- RAM ----
  wire [7:0] ram_dout;
  dmem_s #(DATA, DLOAD) ram(clk, we && (addr < 8'hF0), addr, wdata, ram_dout);   // blok-RAM: synchroon lezen

  // ---- UART zender: 1 startbit, 8 databits (laagste eerst), 1 stopbit ----
  reg [9:0]  tx_frame;
  reg [3:0]  tx_n;
  reg [15:0] tx_cnt;
  wire tx_busy = (tx_n != 0);
  assign txd = tx_busy ? tx_frame[0] : 1'b1;

  // ---- UART ontvanger, met een synchronizer voor de ingang (week 6) ----
  reg rxd_s1, rxd_s2;
  reg        rx_busy, rx_ready;
  reg [3:0]  rx_n;
  reg [15:0] rx_cnt;
  reg [7:0]  rx_shift, rx_data;

  // ---- Timer: telt 'tikken'. Een tik is TDIV klokcycli (TDIV = 1: elke cyclus; op een FPGA bijvoorbeeld 1 ms) ----
  reg [7:0]  t_reload, t_cnt;
  reg        t_pend;
  reg [15:0] t_pre;
  wire       t_tick = (TDIV <= 1) ? 1'b1 : (t_pre == TDIV - 1);

  reg [7:0] irq_en;

  assign irq = (t_pend & irq_en[0]) | (rx_ready & irq_en[1]);

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      tx_frame <= 10'h3FF; tx_n <= 0; tx_cnt <= 0;
      rxd_s1 <= 1; rxd_s2 <= 1; rx_busy <= 0; rx_ready <= 0; rx_n <= 0; rx_cnt <= 0; rx_shift <= 0; rx_data <= 0;
      t_reload <= 0; t_cnt <= 0; t_pend <= 0; t_pre <= 0; irq_en <= 0; gpio_out <= 0;
    end else begin
      // schrijfacties van de CPU
      if (we) case (addr)
        8'hF0: if (!tx_busy) begin tx_frame <= {1'b1, wdata, 1'b0}; tx_n <= 4'd10; tx_cnt <= DIV - 1; end
        8'hF2: t_reload <= wdata;
        8'hF3: t_pend <= 1'b0;
        8'hF5: gpio_out <= wdata;
        8'hF7: irq_en <= wdata;
        default: ;
      endcase

      // zender
      if (tx_busy && !(we && addr == 8'hF0)) begin
        if (tx_cnt == 0) begin
          tx_cnt <= DIV - 1;
          tx_frame <= {1'b1, tx_frame[9:1]};
          tx_n <= tx_n - 1;
        end else tx_cnt <= tx_cnt - 1;
      end

      // ontvanger
      rxd_s1 <= rxd; rxd_s2 <= rxd_s1;
      if (rd && addr == 8'hF0) rx_ready <= 1'b0;
      if (!rx_busy) begin
        if (!rxd_s2) begin rx_busy <= 1; rx_cnt <= DIV / 2; rx_n <= 0; end
      end else begin
        if (rx_cnt == 0) begin
          rx_cnt <= DIV - 1;
          if (rx_n == 0) begin
            if (rxd_s2) rx_busy <= 0;                       // valse start: afbreken
            rx_n <= 1;
          end else if (rx_n <= 8) begin
            rx_shift <= {rxd_s2, rx_shift[7:1]}; rx_n <= rx_n + 1;
          end else begin
            if (rxd_s2) begin rx_data <= rx_shift; rx_ready <= 1'b1; end
            rx_busy <= 0;
          end
        end else rx_cnt <= rx_cnt - 1;
      end

      // timer
      t_pre <= t_tick ? 16'd0 : t_pre + 16'd1;
      if (t_reload != 0) begin
        if (t_tick) begin
          if (t_cnt >= t_reload - 1) begin t_cnt <= 0; t_pend <= 1'b1; end
          else t_cnt <= t_cnt + 1;
        end
      end else t_cnt <= 0;
    end

  // Lezen van de apparaten wordt, net als het RAM, een klokperiode vastgehouden.
  reg [7:0] io_comb, io_q;
  reg       ram_sel_q;
  always_comb begin
    case (addr)
      8'hF0: io_comb = rx_data;
      8'hF1: io_comb = {6'b0, rx_ready, tx_busy};
      8'hF2: io_comb = t_reload;
      8'hF3: io_comb = {7'b0, t_pend};
      8'hF5: io_comb = gpio_out;
      8'hF6: io_comb = gpio_in;
      8'hF7: io_comb = irq_en;
      default: io_comb = 8'h00;
    endcase
  end
  always @(posedge clk) begin
    io_q <= io_comb;
    ram_sel_q <= (addr < 8'hF0);
  end
  always_comb rdata = ram_sel_q ? ram_dout : io_q;
endmodule
