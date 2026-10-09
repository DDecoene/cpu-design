// Controleert de uitwerkingen van de oefeningen van week 17.
module tb_answers;
  reg clk = 0, rst_n = 0;
  wire h1, h2, h3, h4, h5;
  integer fouten = 0, cycli, k;

  cpu #("popcount.hex", 1)                 c_pop (.clk(clk), .rst_n(rst_n), .halted(h1));
  cpu #("add16.hex", 1)                    c_add (.clk(clk), .rst_n(rst_n), .halted(h2));
  cpu #("strlen.hex", 1, "strlen.dat", 1)  c_len (.clk(clk), .rst_n(rst_n), .halted(h3));
  cpu #("reverse.hex", 1)                  c_rev (.clk(clk), .rst_n(rst_n), .halted(h4));
  cpu #("memcpy.hex", 1, "memcpy.dat", 1)  c_cpy (.clk(clk), .rst_n(rst_n), .halted(h5));
  always #5 clk = ~clk;

  initial begin
    #22 rst_n = 1; cycli = 0;
    while (!(h1 && h2 && h3 && h4 && h5) && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
    if (c_pop.dp.r[2] !== 8'd6)                         begin fouten = fouten + 1; $display("FAIL popcount: %0d", c_pop.dp.r[2]); end
    if ({c_add.dp.r[6], c_add.dp.r[5]} !== 16'h0200)    begin fouten = fouten + 1; $display("FAIL add16: %h", {c_add.dp.r[6], c_add.dp.r[5]}); end
    if (c_len.dp.r[2] !== 8'd5)                         begin fouten = fouten + 1; $display("FAIL strlen: %0d", c_len.dp.r[2]); end
    if (c_rev.dp.r[2] !== 8'h2D)                        begin fouten = fouten + 1; $display("FAIL reverse: %h", c_rev.dp.r[2]); end
    for (k = 0; k < 8; k = k + 1)
      if (c_cpy.dm.mem[48 + k] !== c_cpy.dm.mem[16 + k] || c_cpy.dm.mem[48 + k] === 8'h00) begin
        fouten = fouten + 1; $display("FAIL memcpy: byte %0d", k);
      end
    if (fouten == 0) $display("PASS: uitwerkingen (bits tellen, 16-bit optellen, strlen, bits omkeren, memcpy) kloppen");
    $finish;
  end
endmodule
