module tb_control;
  reg clk = 0, rst_n = 1;          // begint hoog; elke test geeft zelf een resetpuls (dalende flank)
  reg [3:0] op = 0;
  reg [2:0] cond = 0;
  reg fz = 0, fn = 0, fc = 0, fv = 0;
  wire pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel, alu_ir, flags_we, mem_we, halted;
  wire [1:0] wb_sel, b_sel;
  wire [2:0] alu_op;
  integer fouten = 0, i, f;

  control dut(clk, rst_n, op, cond, fz, fn, fc, fv,
              pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel, alu_ir, flags_we, mem_we,
              wb_sel, b_sel, alu_op, halted);
  always #5 clk = ~clk;

  // Alle besturingssignalen als één vector, in vaste volgorde.
  wire [18:0] signalen = {pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel,
                          alu_ir, flags_we, mem_we, wb_sel, b_sel, alu_op};

  function [18:0] w(input pi, pl, ps, iw, rw, w7, ras, rbs, ai, fw, mw,
                    input [1:0] wb, bs, input [2:0] ao);
    w = {pi, pl, ps, iw, rw, w7, ras, rbs, ai, fw, mw, wb, bs, ao};
  endfunction

  // Verwachte uitvoerstap per opcode (uit de tabel in de cursus).
  task check_op(input [3:0] o, input [18:0] verwacht, input [255:0] naam);
    begin
      rst_n = 0; #1; rst_n = 1;
      op = o; cond = 3'd0;             // voorwaarde 'altijd'
      #1;
      if (signalen !== w(1,0,0,1,0,0,0,0,0,0,0,0,0,0)) begin fouten = fouten + 1; $display("FAIL %0s: ophaalstap = %b", naam, signalen); end
      @(posedge clk); #1;              // naar stap 1: uitvoeren
      if (signalen !== verwacht) begin fouten = fouten + 1; $display("FAIL %0s: uitvoerstap = %b, verwacht %b", naam, signalen, verwacht); end
    end
  endtask

  function cond_ref(input [2:0] c, input z, n, cy, v);
    case (c)
      0: cond_ref = 1;      1: cond_ref = z;        2: cond_ref = !z;      3: cond_ref = cy;
      4: cond_ref = !cy;    5: cond_ref = n ^ v;    6: cond_ref = !(n ^ v); default: cond_ref = n;
    endcase
  endfunction

  initial begin
    //                 pi pl ps iw rw w7 ra rb ai fw mw wb  bs  alu_op
    check_op(4'h0, w(0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0), "ALU");
    check_op(4'h1, w(0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 0, 0), "LDI");
    check_op(4'h2, w(0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0), "ADDI");
    check_op(4'h3, w(0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 2, 0), "LD");
    check_op(4'h4, w(0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 2, 0), "ST");
    check_op(4'h6, w(0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1), "CMP");
    check_op(4'h7, w(0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1), "CMPI");
    check_op(4'h8, w(0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 3, 0, 0), "CALL");
    check_op(4'h9, w(0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), "JR");
    check_op(4'hA, w(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), "NOP");
    check_op(4'hC, w(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), "ongebruikt");

    // Voorwaardelijke sprong: alle 8 voorwaarden x alle 16 vlaggencombinaties.
    for (i = 0; i < 8; i = i + 1)
      for (f = 0; f < 16; f = f + 1) begin
        rst_n = 0; #1; rst_n = 1;
        op = 4'h5; cond = i; {fz, fn, fc, fv} = f; @(posedge clk); #1;
        if (pc_load !== cond_ref(i, fz, fn, fc, fv)) begin
          fouten = fouten + 1; $display("FAIL Bcc cond=%0d vlaggen=%b: pc_load=%b", i, f[3:0], pc_load);
        end
      end

    // HALT: na de uitvoerstap staat halted aan en doet de besturing niets meer.
    rst_n = 0; #1; rst_n = 1; op = 4'hF;
    @(posedge clk); #1;
    @(posedge clk); #1;
    if (halted !== 1'b1) begin fouten = fouten + 1; $display("FAIL: halted niet gezet"); end
    if (signalen !== 19'b0) begin fouten = fouten + 1; $display("FAIL: besturing blijft actief na HALT"); end
    @(posedge clk); #1;
    if (signalen !== 19'b0 || !halted) begin fouten = fouten + 1; $display("FAIL: HALT niet blijvend"); end

    if (fouten == 0) $display("PASS: besturingseenheid levert voor elke opcode de juiste signalen");
    $finish;
  end
endmodule
