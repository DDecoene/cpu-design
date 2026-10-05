// FILE: beeld/tb_vga_sync.v
// Controleert de VGA-timing met losse tellers die de getallen uit de specificatie letterlijk gebruiken.
module tb_vga_sync;
  reg pclk = 0, rst_n = 0;
  wire hsync, vsync, active, vblank;
  wire [10:0] x, y;
  integer fouten = 0;

  vga_sync dut(.pclk(pclk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync), .active(active), .vblank(vblank), .x(x), .y(y));
  always #20 pclk = ~pclk;

  integer t = 0;                          // klokcycli sinds de reset
  integer hs_fall = -1, vs_fall = -1;
  integer frames = 0, actief = 0, laatste_actief = -1;
  reg hs_p = 1, vs_p = 1;

  task check(input cond, input [8*60-1:0] tekst);
    if (!cond) begin fouten = fouten + 1; $display("FAIL: %0s (t=%0d)", tekst, t); end
  endtask

  always @(posedge pclk) if (rst_n) begin
    t = t + 1;
    if (active) begin
      actief = actief + 1;
      laatste_actief = t;
      if (x >= 640 || y >= 480) check(0, "actief buiten 640 x 480");
    end
    if ((y >= 480) !== vblank) check(0, "vblank hoort bij y >= 480");
    // horizontale sync
    if (hs_p && !hsync) begin
      check(x === 656, "hsync begint na 640 pixels plus 16 front porch");
      if (hs_fall >= 0) check(t - hs_fall == 800, "een lijn duurt 800 klokken");
      if (y < 480) check(t - laatste_actief == 17, "front porch: 16 klokken tussen de laatste pixel en de sync");
      hs_fall = t;
    end
    if (!hs_p && hsync) check(t - hs_fall == 96, "horizontale sync is 96 klokken laag");
    // verticale sync
    if (vs_p && !vsync) begin
      check(y === 490 && x === 0, "vsync begint na 480 lijnen plus 10 front porch");
      if (vs_fall >= 0) begin
        check(t - vs_fall == 525 * 800, "een beeld duurt 525 lijnen");
        check(actief == 640 * 480, "307200 actieve pixels per beeld");
        frames = frames + 1;
      end
      vs_fall = t; actief = 0;
    end
    if (!vs_p && vsync) check(t - vs_fall == 2 * 800, "verticale sync is 2 lijnen laag");
    hs_p = hsync; vs_p = vsync;
  end

  initial begin
    #100 rst_n = 1;
    wait (frames == 2);
    if (fouten == 0) $display("PASS: 800 x 525 klokken, syncbreedtes 96 en 2 lijnen, 307200 actieve pixels, front porch 16");
    $finish;
  end
endmodule
