`timescale 1ns/1ps
// De hele keten: de CPU voert kleurbalken.asm uit, schrijft de balken in het framebuffer, en we kijken met de virtuele monitor wat er op het scherm staat.
module tb_beeld_v;
  reg clk = 0, pclk = 0, rst_n = 0;
  wire hsync, vsync, txd, frame_done;
  wire [3:0] r, g, b;
  wire [7:0] gpio;
  wire [31:0] frames;
  integer fouten = 0, x, y;
  reg [11:0] pal [0:15];

  beeld_v #("kleurbalken.hex") dut(.clk(clk), .pclk(pclk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b),
                                   .txd(txd), .rxd(1'b1), .gpio_in(8'h00), .gpio_out(gpio));
  vga_mon mon(.pclk(pclk), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .frame_done(frame_done), .frames(frames));
  always #41.667 clk = ~clk;
  always #19.9 pclk = ~pclk;

  initial begin
    pal[0]=12'h000; pal[1]=12'h00A; pal[2]=12'h0A0; pal[3]=12'h0AA; pal[4]=12'hA00; pal[5]=12'hA0A; pal[6]=12'hA50; pal[7]=12'hAAA;
    pal[8]=12'h555; pal[9]=12'h55F; pal[10]=12'h5F5; pal[11]=12'h5FF; pal[12]=12'hF55; pal[13]=12'hF5F; pal[14]=12'hFF5; pal[15]=12'hFFF;
    #200 rst_n = 1;
    wait (gpio[0] === 1'b1);                         // het programma meldt dat het klaar is
    $display("de CPU is klaar op t = %0t", $time);
    wait (frames >= 1);
    frames_na_klaar();
    // wacht op een volledig beeld dat helemaal na het tekenen begon
    $finish;
  end

  task frames_na_klaar;
    reg [31:0] f0;
    begin
      f0 = frames;
      wait (frames == f0 + 2);                        // het eerste beeld erna kan nog half oud zijn; het tweede is zeker nieuw
      #1;
      if (mon.painted_last !== 640 * 480) begin fouten = fouten + 1; $display("FAIL: %0d pixels geschilderd", mon.painted_last); end
      for (y = 0; y < 480; y = y + 1)
        for (x = 0; x < 640; x = x + 1)
          if (mon.img[y*640 + x] !== pal[x / 40] && fouten < 10) begin
            fouten = fouten + 1; $display("FAIL: pixel (%0d,%0d) is %h, verwacht %h", x, y, mon.img[y*640 + x], pal[x / 40]);
          end
      mon.write_ppm("../../build/kleurbalken.ppm");
      if (fouten == 0) $display("PASS: de CPU tekent 16 kleurbalken en het scherm toont ze op de goede plek");
    end
  endtask
endmodule
