// FILE: beeld/tb_vga_testbeeld.v
// Het testbeeld bekijken met de virtuele monitor en elke pixel van het eerste volledige beeld controleren.
module tb_vga_testbeeld;
  reg pclk = 0, rst_n = 0;
  wire hsync, vsync;
  wire [3:0] r, g, b;
  wire frame_done;
  wire [31:0] frames;
  integer fouten = 0, x, y, bar;
  reg [11:0] verwacht;

  vga_testbeeld dut(.pclk(pclk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b));
  vga_mon mon(.pclk(pclk), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .frame_done(frame_done), .frames(frames));
  always #20 pclk = ~pclk;

  initial begin
    #100 rst_n = 1;
    wait (frames == 1);
    #1;
    if (mon.painted_last !== 640 * 480) begin fouten = fouten + 1; $display("FAIL: %0d pixels geschilderd, verwacht 307200", mon.painted_last); end
    if (mon.unknown_last !== 0) begin fouten = fouten + 1; $display("FAIL: %0d onbekende pixels", mon.unknown_last); end
    for (y = 0; y < 480; y = y + 1)
      for (x = 0; x < 640; x = x + 1) begin
        bar = x / 80;
        if (x == 0 || x == 639 || y == 0 || y == 479) verwacht = 12'hFFF;
        else if (y < 320) verwacht = {{4{bar[2]}}, {4{bar[1]}}, {4{bar[0]}}};
        else verwacht = {3{x[7:4]}};
        if (mon.img[y*640 + x] !== verwacht && fouten < 10) begin
          fouten = fouten + 1; $display("FAIL: pixel (%0d,%0d) is %h, verwacht %h", x, y, mon.img[y*640 + x], verwacht);
        end
      end
    mon.write_ppm("../../build/testbeeld.ppm");
    if (fouten == 0) $display("PASS: alle 307200 pixels van het testbeeld liggen op de goede plek");
    $finish;
  end
endmodule
