module tb_fifo;
  reg clk = 0, rst_n = 0, push = 0, pop = 0;
  reg  [7:0] din = 0;
  wire [7:0] dout;
  wire full, empty;
  integer i, fouten = 0, keer_vol = 0, keer_leeg = 0;

  // Referentiemodel: een gewone array met een schrijf- en leesindex, zonder hardware-trucs.
  reg [7:0] m_mem [0:7];
  integer m_wp = 0, m_rp = 0, m_count = 0;

  fifo #(8, 3) dut(clk, rst_n, push, pop, din, dout, full, empty);
  always #5 clk = ~clk;

  // Stimulus: willekeurig pushen en poppen, aangestuurd op de dalende flank.
  initial begin
    #12 rst_n = 1;
    for (i = 0; i < 20000; i = i + 1) begin
      @(negedge clk);
      push = $random; pop = $random; din = $random;
    end
    @(posedge clk); #2;
    if (fouten == 0 && keer_vol > 100 && keer_leeg > 100)
      $display("PASS: fifo klopt over 20000 willekeurige cycli (%0d keer vol, %0d keer leeg gezien)", keer_vol, keer_leeg);
    else
      $display("FAIL: fouten=%0d vol=%0d leeg=%0d", fouten, keer_vol, keer_leeg);
    $finish;
  end

  // Monitor: werk het model bij met dezelfde regels en vergelijk met het ontwerp.
  always @(posedge clk) if (rst_n) begin : monitor
    integer do_push, do_pop;
    do_push = push && (m_count < 8);
    do_pop  = pop  && (m_count > 0);
    if (do_push) begin m_mem[m_wp % 8] = din; m_wp = m_wp + 1; end
    if (do_pop)  m_rp = m_rp + 1;
    m_count = m_count + do_push - do_pop;
    #1;                                  // wacht tot het ontwerp zijn uitgangen heeft bijgewerkt
    if (full  !== (m_count == 8)) begin fouten = fouten + 1; $display("FAIL full bij %0t", $time); end
    if (empty !== (m_count == 0)) begin fouten = fouten + 1; $display("FAIL empty bij %0t", $time); end
    if (m_count > 0 && dout !== m_mem[m_rp % 8]) begin
      fouten = fouten + 1; $display("FAIL data bij %0t: %h i.p.v. %h", $time, dout, m_mem[m_rp % 8]);
    end
    if (full)  keer_vol  = keer_vol + 1;
    if (empty) keer_leeg = keer_leeg + 1;
  end
endmodule
