module tb_cache;
  reg clk = 0, rst_n = 0, req = 0, we = 0;
  reg  [7:0] addr = 0, wdata = 0;
  wire [7:0] rdata;
  wire ready;
  wire [31:0] hits, misses;
  integer fouten = 0, i, p, k, cyc, t0, totaal, hits_start, miss_start;
  reg [7:0] model [0:255];
  reg [7:0] want;

  cache #(4) dut(clk, rst_n, req, we, addr, wdata, rdata, ready, hits, misses);
  always #5 clk = ~clk;
  always @(posedge clk) cyc = cyc + 1;

  // Eén aanvraag: stuur en wacht tot ready. Geeft de gelezen waarde in 'want_out' via rdata.
  task access(input is_write, input [7:0] a, input [7:0] w);
    begin
      @(negedge clk);
      req = 1; we = is_write; addr = a; wdata = w;
      @(posedge clk);
      while (!ready) @(posedge clk);
      @(negedge clk);
      req = 0; we = 0;
    end
  endtask

  task nulmeting; begin hits_start = hits; miss_start = misses; t0 = cyc; end endtask

  initial begin
    cyc = 0;
    #22 rst_n = 1;
    // Beginwaarden in het hoofdgeheugen en in het model.
    for (i = 0; i < 256; i = i + 1) begin model[i] = $random; dut.backing.mem[i] = model[i]; end

    // ---- 1. Functioneel: 20000 willekeurige lees- en schrijfacties tegen een referentiemodel ----
    for (i = 0; i < 20000; i = i + 1) begin
      k = {$random} % 256;
      if ({$random} % 2) begin
        want = $random; access(1, k[7:0], want); model[k] = want;
      end else begin
        access(0, k[7:0], 8'h00);
        if (rdata !== model[k]) begin fouten = fouten + 1; if (fouten < 10) $display("FAIL: lees %0d gaf %0d i.p.v. %0d", k, rdata, model[k]); end
      end
    end
    // Alles wat in het hoofdgeheugen staat moet het model zijn (write-through).
    for (i = 0; i < 256; i = i + 1)
      if (dut.backing.mem[i] !== model[i]) begin fouten = fouten + 1; $display("FAIL: hoofdgeheugen[%0d]", i); end
    $display("willekeurig: %0d treffers, %0d missers", hits, misses);

    // ---- 2. Prestaties met gerichte toegangspatronen ----
    // Koude cache: ongeldig maken door reset.
    rst_n = 0; #1; rst_n = 1; @(negedge clk);

    // a) Scan van 64 bytes (past precies in de cache), 10 keer: 16 missers, de rest treffers.
    nulmeting;
    for (p = 0; p < 10; p = p + 1) for (i = 0; i < 64; i = i + 1) access(0, i[7:0], 8'h00);
    totaal = (hits - hits_start) + (misses - miss_start);
    $display("scan 0..63 x10: %0d toegangen, %0d treffers, %0d missers, %0d cycli", totaal, hits - hits_start, misses - miss_start, cyc - t0);
    if (misses - miss_start !== 16 || hits - hits_start !== 624) begin fouten = fouten + 1; $display("FAIL: scan-telling"); end

    // b) Stap van 64 (0, 64, 128, 192): alle vier botsen op dezelfde regel: nooit een treffer.
    rst_n = 0; #1; rst_n = 1; @(negedge clk);
    nulmeting;
    for (p = 0; p < 100; p = p + 1) for (i = 0; i < 4; i = i + 1) access(0, (i * 64), 8'h00);
    $display("stap 64 x100: %0d treffers, %0d missers", hits - hits_start, misses - miss_start);
    if (hits - hits_start !== 0 || misses - miss_start !== 400) begin fouten = fouten + 1; $display("FAIL: botsingen"); end

    // c) Een werkset van 4 regels (16 bytes) 100 keer: alleen de eerste ronde mist.
    rst_n = 0; #1; rst_n = 1; @(negedge clk);
    nulmeting;
    for (p = 0; p < 100; p = p + 1) for (i = 0; i < 16; i = i + 1) access(0, i[7:0], 8'h00);
    $display("werkset 16 bytes x100: %0d treffers, %0d missers", hits - hits_start, misses - miss_start);
    if (misses - miss_start !== 4 || hits - hits_start !== 1596) begin fouten = fouten + 1; $display("FAIL: werkset"); end

    if (fouten == 0) $display("PASS: de cache geeft altijd de juiste data en gedraagt zich zoals de theorie voorspelt");
    $finish;
  end
endmodule
