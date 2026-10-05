// FILE: tt_t8/tt_t8.v
// Het toplevel voor Tiny Tapeout: de T8 als kleine chip. De poortnamen volgen de afspraak van het project.
//   ui_in  = de ingangspoort (IN)        uo_out  = de uitgangspoort (OUT)
//   uio_out = debug: {halted, 0, programmateller}
module tt_um_t8_tta (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);
  wire [5:0]  pc_addr;
  wire [23:0] instr;
  wire        halted;

  t8_rom rom (.a(pc_addr), .d(instr));
  t8_core #(.PCW(6), .AW(3)) core (
    .clk(clk), .rst_n(rst_n), .in_port(ui_in), .out_port(uo_out), .halted(halted),
    .rom_addr(pc_addr), .instr(instr),
    .r0(), .r1(), .r2(), .r3(), .op_out(), .res_out(), .flag_z(), .flag_n(), .flag_c()
  );

  assign uio_out = {halted, 1'b0, pc_addr};
  assign uio_oe  = 8'hFF;                       // alle bidirectionele pennen zijn uitgangen
  wire _unused = &{ena, uio_in, 1'b0};
endmodule
