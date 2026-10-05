// FILE: week08/tb_mem.v
module tb_mem;
  reg clk = 0, we = 0;
  reg  [7:0] addr = 0, din = 0;
  wire [7:0] dout;
  wire [7:0] rom_out;
  reg  [3:0] rom_addr = 0;
  integer i, fouten = 0;

  ram #(8, 8) r(clk, we, addr, din, dout);
  rom #(4, 8, "prog.hex") m(rom_addr, rom_out);

  always #5 clk = ~clk;

  initial begin
    // Schrijf 16 waarden in het RAM en lees ze terug.
    for (i = 0; i < 16; i = i + 1) begin
      @(negedge clk); addr = i[7:0]; din = i[7:0] * 8'd3 + 8'd7; we = 1;
      @(negedge clk); we = 0;
    end
    for (i = 0; i < 16; i = i + 1) begin
      addr = i[7:0]; #1;
      if (dout !== (i[7:0] * 8'd3 + 8'd7)) begin fouten = fouten + 1; $display("FAIL ram %0d", i); end
    end
    // Zonder we verandert er niets.
    @(negedge clk); addr = 8'd2; din = 8'hEE; we = 0;
    @(negedge clk); if (dout !== 8'd13) begin fouten = fouten + 1; $display("FAIL: schreef zonder we"); end

    // ROM: de bestandsinhoud komt terug.
    rom_addr = 0; #1; if (rom_out !== 8'hA1) begin fouten = fouten + 1; $display("FAIL rom 0: %h", rom_out); end
    rom_addr = 3; #1; if (rom_out !== 8'h3C) begin fouten = fouten + 1; $display("FAIL rom 3: %h", rom_out); end
    rom_addr = 7; #1; if (rom_out !== 8'h5A) begin fouten = fouten + 1; $display("FAIL rom 7: %h", rom_out); end
    rom_addr = 12; #1; if (rom_out !== 8'h00) begin fouten = fouten + 1; $display("FAIL rom leeg: %h", rom_out); end

    if (fouten == 0) $display("PASS: RAM en ROM werken");
    $finish;
  end
endmodule
