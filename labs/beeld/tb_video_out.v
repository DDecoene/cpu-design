// FILE: beeld/tb_video_out.v
`timescale 1ns/1ps
// Schrijft een patroon rechtstreeks in het framebuffer (zonder CPU) en controleert elke pixel van het scherm.
// De twee klokken zijn bewust niet gelijk en niet synchroon: 12 MHz voor het schrijven, 25,125 MHz voor het beeld.
module tb_video_out;
  reg wclk = 0, pclk = 0, rst_n = 0;
  reg we = 0;
  reg [13:0] waddr = 0;
  reg [7:0] wdata = 0;
  wire hsync, vsync, vblank, frame_done;
  wire [3:0] r, g, b;
  wire [31:0] frames;
  integer fouten = 0, i, x, y, bx, idx;
  reg [7:0] byte_i;
  reg [11:0] pal [0:15];
  reg [11:0] verwacht;

  video_out dut(.pclk(pclk), .rst_n(rst_n), .wclk(wclk), .we(we), .waddr(waddr), .wdata(wdata),
                .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .vblank(vblank));
  vga_mon mon(.pclk(pclk), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .frame_done(frame_done), .frames(frames));
  always #41.667 wclk = ~wclk;
  always #19.9 pclk = ~pclk;

  // Het patroon: byte i krijgt een waarde die van i afhangt, zodat een verkeerd adres of een verwisselde nibble opvalt.
  function [7:0] patroon(input integer n);
    patroon = (n * 7 + n / 80 * 3 + 1) & 8'hFF;
  endfunction

  initial begin
    // een eigen kopie van de palette, onafhankelijk van de code in video_out
    pal[0]=12'h000; pal[1]=12'h00A; pal[2]=12'h0A0; pal[3]=12'h0AA; pal[4]=12'hA00; pal[5]=12'hA0A; pal[6]=12'hA50; pal[7]=12'hAAA;
    pal[8]=12'h555; pal[9]=12'h55F; pal[10]=12'h5F5; pal[11]=12'h5FF; pal[12]=12'hF55; pal[13]=12'hF5F; pal[14]=12'hFF5; pal[15]=12'hFFF;
    #200 rst_n = 1;
    for (i = 0; i < 9600; i = i + 1) begin
      @(posedge wclk); #1;
      we = 1; waddr = i; wdata = patroon(i);
    end
    @(posedge wclk); #1 we = 0;
    wait (frames == 2);                       // het tweede volledige beeld heeft het hele patroon
    #1;
    if (mon.painted_last !== 640 * 480) begin fouten = fouten + 1; $display("FAIL: %0d pixels geschilderd", mon.painted_last); end
    if (mon.unknown_last !== 0) begin fouten = fouten + 1; $display("FAIL: %0d onbekende pixels", mon.unknown_last); end
    for (y = 0; y < 480; y = y + 1)
      for (x = 0; x < 640; x = x + 1) begin
        bx = x / 4;
        byte_i = patroon((y / 4) * 80 + bx / 2);
        idx = (bx % 2 == 0) ? byte_i[7:4] : byte_i[3:0];     // linker blok = hoge nibble
        verwacht = pal[idx];
        if (mon.img[y*640 + x] !== verwacht && fouten < 10) begin
          fouten = fouten + 1; $display("FAIL: pixel (%0d,%0d) is %h, verwacht %h", x, y, mon.img[y*640 + x], verwacht);
        end
      end
    mon.write_ppm("../../build/video_out.ppm");
    if (fouten == 0) $display("PASS: het framebuffer verschijnt pixel voor pixel goed op het scherm, met twee ongelijke klokken");
    $finish;
  end
endmodule
