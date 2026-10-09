// Test van interrupts en apparaten: timer, UART met polling, UART met interrupt.
module tb_irq;
  localparam DIV = 16;
  reg clk = 0, rst_n = 0;
  integer fouten = 0, cycli, k;

  // --- A: timer-interrupt tegenover dezelfde berekening zonder interrupts ---
  wire ha, hb, ta, tb_;
  wire [7:0] a_r0, a_r1, a_r3, b_r0, b_r1, b_r3;
  cpu_i #("timer.hex", 1, DIV) ca(.clk(clk), .rst_n(rst_n), .halted(ha), .r0(a_r0), .r1(a_r1), .r3(a_r3),
                                  .rxd(1'b1), .gpio_in(8'd0));
  cpu_i #("timer_uit.hex", 1, DIV) cb(.clk(clk), .rst_n(rst_n), .halted(hb), .r0(b_r0), .r1(b_r1), .r3(b_r3),
                                      .rxd(1'b1), .gpio_in(8'd0));

  // --- B: UART met polling, zender aangesloten op eigen ontvanger ---
  wire hc, txd_c;
  cpu_i #("uart.hex", 1, DIV) cc(.clk(clk), .rst_n(rst_n), .halted(hc), .txd(txd_c), .rxd(txd_c), .gpio_in(8'd0));

  // --- C: UART-ontvangst met interrupt, de testbench zendt de bytes ---
  wire hd;
  reg  rxd_d = 1;
  cpu_i #("uart_irq.hex", 1, DIV) cd(.clk(clk), .rst_n(rst_n), .halted(hd), .rxd(rxd_d), .gpio_in(8'd0));

  always #5 clk = ~clk;

  // Een onafhankelijke UART-ontvanger voor de zenderlijn van B, om de frames te controleren.
  reg [7:0] gezien [0:7];
  integer n_gezien = 0;
  initial begin : monitor_tx
    reg [7:0] b;
    integer i;
    forever begin
      @(negedge txd_c);                         // begin van een startbit
      repeat (DIV + DIV / 2) @(posedge clk);    // naar het midden van databit 0
      for (i = 0; i < 8; i = i + 1) begin
        b[i] = txd_c;
        repeat (DIV) @(posedge clk);
      end
      if (txd_c !== 1'b1) begin fouten = fouten + 1; $display("FAIL: geen stopbit"); end
      gezien[n_gezien] = b; n_gezien = n_gezien + 1;
    end
  end

  // Bytes verzenden naar de ontvanger van C
  task stuur(input [7:0] b);
    integer i;
    begin
      rxd_d = 0; repeat (DIV) @(posedge clk);                 // startbit
      for (i = 0; i < 8; i = i + 1) begin rxd_d = b[i]; repeat (DIV) @(posedge clk); end
      rxd_d = 1; repeat (DIV) @(posedge clk);                 // stopbit
    end
  endtask

  initial begin
    #22 rst_n = 1;
    fork
      begin : zenden
        repeat (300) @(posedge clk);
        stuur(8'h41);
        repeat (200) @(posedge clk);
        stuur(8'h42);
        repeat (37) @(posedge clk);
        stuur(8'h43);
      end
    join_none
    cycli = 0;
    while (!(ha && hb && hc && hd) && cycli < 200000) begin @(negedge clk); cycli = cycli + 1; end
    if (cycli >= 200000) begin fouten = fouten + 1; $display("FAIL: niet alles stopte (a=%b b=%b c=%b d=%b)", ha, hb, hc, hd); end

    // A: de hoofdberekening is onaangetast door de interrupts
    $display("timer: ISR draaide %0d keer", ca.io.ram.mem[8'h20]);
    if (a_r1 !== 8'd132 || b_r1 !== 8'd132) begin fouten = fouten + 1; $display("FAIL A: R1 = %0d / %0d", a_r1, b_r1); end
    if (a_r3 !== 8'd0 || b_r3 !== 8'd0)     begin fouten = fouten + 1; $display("FAIL A: R3"); end
    if (a_r0 !== 8'd0 || b_r0 !== 8'd0)     begin fouten = fouten + 1; $display("FAIL A: R0 niet hersteld: %0d", a_r0); end
    if (ca.io.ram.mem[8'h20] < 8'd10)        begin fouten = fouten + 1; $display("FAIL A: te weinig interrupts"); end
    if (cb.io.ram.mem[8'h20] !== 8'd0)       begin fouten = fouten + 1; $display("FAIL A: referentie kreeg interrupts"); end

    // B: de frames op de lijn zijn 'H' en 'I', en de ontvanger heeft ze ook gezien
    if (n_gezien !== 2 || gezien[0] !== 8'h48 || gezien[1] !== 8'h49) begin fouten = fouten + 1; $display("FAIL B: lijn %0d bytes: %h %h", n_gezien, gezien[0], gezien[1]); end
    if (cc.io.ram.mem[8'h30] !== 8'h48 || cc.io.ram.mem[8'h31] !== 8'h49) begin
      fouten = fouten + 1; $display("FAIL B: ontvangen %h %h", cc.io.ram.mem[8'h30], cc.io.ram.mem[8'h31]);
    end

    // C: drie bytes via interrupts in de buffer
    if (cd.io.ram.mem[8'h21] !== 8'd3) begin fouten = fouten + 1; $display("FAIL C: aantal = %0d", cd.io.ram.mem[8'h21]); end
    if (cd.io.ram.mem[8'h30] !== 8'h41 || cd.io.ram.mem[8'h31] !== 8'h42 || cd.io.ram.mem[8'h32] !== 8'h43) begin
      fouten = fouten + 1; $display("FAIL C: buffer %h %h %h", cd.io.ram.mem[8'h30], cd.io.ram.mem[8'h31], cd.io.ram.mem[8'h32]);
    end

    if (fouten == 0) $display("PASS: timer-interrupt (transparant), UART-polling en UART-interrupt werken");
    $finish;
  end
endmodule
