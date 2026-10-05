// FILE: beeld/tb_video_io.v
// De videoregisters via de buslijnen van de CPU: adres instellen, auto-increment, grens bij 9600 en de vblank-status.
module tb_video_io;
  reg clk = 0, rst_n = 0, sel = 0, we = 0, vb = 0;
  reg [1:0] reg_sel = 0;
  reg [7:0] wdata = 0;
  wire [7:0] rdata;
  wire fb_we;
  wire [13:0] fb_waddr;
  wire [7:0] fb_wdata;
  integer fouten = 0, n_writes = 0;

  video_io dut(.clk(clk), .rst_n(rst_n), .sel(sel), .we(we), .reg_sel(reg_sel), .wdata(wdata), .rdata(rdata),
               .vblank_p(vb), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata));
  always #5 clk = ~clk;

  always @(posedge clk) if (fb_we) n_writes = n_writes + 1;

  task schrijf(input [1:0] r, input [7:0] d);
    begin
      @(negedge clk); sel = 1; we = 1; reg_sel = r; wdata = d;
      @(negedge clk); sel = 0; we = 0;
    end
  endtask
  task verwacht(input [13:0] adres, input [7:0] data);
    begin
      @(negedge clk); sel = 1; we = 1; reg_sel = 2; wdata = data;
      #1;
      if (!fb_we || fb_waddr !== adres || fb_wdata !== data) begin fouten = fouten + 1; $display("FAIL: schrijf op %0d: fb_we=%b adres=%0d data=%h", adres, fb_we, fb_waddr, fb_wdata); end
      @(negedge clk); sel = 0; we = 0;
    end
  endtask
  task lees(input [1:0] r, output [7:0] d);
    begin @(negedge clk); sel = 1; reg_sel = r; #1 d = rdata; @(negedge clk); sel = 0; end
  endtask

  reg [7:0] v;
  initial begin
    #22 rst_n = 1;
    schrijf(0, 8'h34); schrijf(1, 8'h12);                    // adres 0x1234 = 4660
    lees(0, v); if (v !== 8'h34) begin fouten = fouten + 1; $display("FAIL: FB_LO leest %h", v); end
    lees(1, v); if (v !== 8'h12) begin fouten = fouten + 1; $display("FAIL: FB_HI leest %h", v); end
    verwacht(14'h1234, 8'hAB);
    verwacht(14'h1235, 8'hCD);                                // het adres liep vanzelf op
    lees(0, v); if (v !== 8'h36) begin fouten = fouten + 1; $display("FAIL: na twee schrijfacties staat FB_LO op %h", v); end
    // naar het einde van het framebuffer
    schrijf(0, 8'h7E); schrijf(1, 8'h25);                    // 0x257E = 9598
    n_writes = 0;
    verwacht(14'd9598, 8'h01);
    verwacht(14'd9599, 8'h02);
    @(negedge clk); sel = 1; we = 1; reg_sel = 2; wdata = 8'h03; #1;   // adres 9600: buiten het framebuffer
    if (fb_we) begin fouten = fouten + 1; $display("FAIL: schrijven op adres 9600 mag niet"); end
    @(negedge clk); sel = 0; we = 0;
    lees(0, v);
    if (v !== 8'h80) begin fouten = fouten + 1; $display("FAIL: het adres moet bij 9600 (0x2580) stoppen, FB_LO = %h", v); end
    // status: de vblank-ingang komt twee klokken later aan
    lees(3, v); if (v[0] !== 1'b0) begin fouten = fouten + 1; $display("FAIL: status zou 0 moeten zijn"); end
    vb = 1; repeat (3) @(negedge clk);
    lees(3, v); if (v[0] !== 1'b1) begin fouten = fouten + 1; $display("FAIL: status zou 1 moeten zijn"); end
    // niet-geselecteerde schrijfacties doen niets
    @(negedge clk); sel = 0; we = 1; reg_sel = 2; wdata = 8'hFF; #1;
    if (fb_we) begin fouten = fouten + 1; $display("FAIL: zonder sel mag er niet geschreven worden"); end
    @(negedge clk); we = 0;
    if (fouten == 0) $display("PASS: video_io: adres, auto-increment, begrenzing en vblank-status kloppen");
    $finish;
  end
endmodule
