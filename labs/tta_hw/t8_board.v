// FILE: tta_hw/t8_board.v
`timescale 1ns/1ps
// De transport-triggered architecture T8 uit echte 74HC-chips. Dit bestand is het schema in tekstvorm:
// elke 'u_...' is één chip op de printplaat, elke 'wire' een draad.
//
// Timing in één oogopslag (klok 'clk'):
//   - de programmateller (PC) telt of laadt op de STIJGENDE flank van clk;
//   - daarna zoekt het ROM de instructie op en settelen de decoders en de bus (de eerste helft van de cyclus);
//   - op de DALENDE flank van clk gaat phi hoog en krijgt het doelregister een kort klokpuls: de MOVE gebeurt dan;
//   - 'halted' reageert op de volgende stijgende flank.
module t8_board #(parameter PROG = "tta.hex", parameter LOAD = 1) (
  input        clk,
  input        rst_n,
  input  [7:0] in_port,
  output [7:0] out_port,
  output       halted
);
  tri0 [7:0] bus;                 // de gedeelde bus; tri0 = de pull-down-weerstanden op de print
  tri0 [7:0] rbus;                // de resultaatbus van de rekeneenheid

  // ===== Programmateller, adresbuffer en programmageheugen =====
  wire [7:0] pc, pc_addr;
  wire       pc_rco, load_pc_n, halted_n;
  hc161 u_pc_lo (.CLK(clk), .CLR_n(rst_n), .LOAD_n(load_pc_n), .ENP(halted_n), .ENT(halted_n),
                 .D(bus[3:0]), .Q(pc[3:0]), .RCO(pc_rco));
  hc161 u_pc_hi (.CLK(clk), .CLR_n(rst_n), .LOAD_n(load_pc_n), .ENP(halted_n), .ENT(pc_rco),
                 .D(bus[7:4]), .Q(pc[7:4]), .RCO());
  hc244 u_pc_buf (.A(pc), .OE_n(1'b0), .Y(pc_addr));       // buffer: iets extra vertraging op het ROM-adres, voor houdtijd

  wire [7:0] rom_hi, rom_mid, rom_lo;
  eeprom28c256 #(PROG, 2, LOAD) u_rom_hi  (.A(pc_addr), .CE_n(1'b0), .OE_n(1'b0), .D(rom_hi));    // guard + bestemming
  eeprom28c256 #(PROG, 1, LOAD) u_rom_mid (.A(pc_addr), .CE_n(1'b0), .OE_n(1'b0), .D(rom_mid));   // bron
  eeprom28c256 #(PROG, 0, LOAD) u_rom_lo  (.A(pc_addr), .CE_n(1'b0), .OE_n(1'b0), .D(rom_lo));    // constante
  wire [2:0] guard = rom_hi[7:5];
  wire [4:0] dst   = rom_hi[4:0];
  wire [4:0] src   = rom_mid[4:0];

  // ===== Vlaggen en guard =====
  wire zf, zf_n, nf, nf_n, cf, cf_n, res_clk, z_next, n_next, c_next;
  hc74 u_fz (.D(z_next), .CLK(res_clk), .CLR_n(rst_n), .SET_n(1'b1), .Q(zf), .Qn(zf_n));
  hc74 u_fn (.D(n_next), .CLK(res_clk), .CLR_n(rst_n), .SET_n(1'b1), .Q(nf), .Qn(nf_n));
  hc74 u_fc (.D(c_next), .CLK(res_clk), .CLR_n(rst_n), .SET_n(1'b1), .Q(cf), .Qn(cf_n));

  wire go;      // mag deze move doorgaan? De guard kiest welke vlag meetelt.
  hc151 u_guard (.D({1'b0, nf_n, nf, cf_n, cf, zf_n, zf, 1'b1}), .S0(guard[0]), .S1(guard[1]), .S2(guard[2]),
                 .E_n(1'b0), .Y(go), .W());

  // ===== Bestemmingsdecoders (74HC238): LEVELS, stabiel zodra het ROM settled is =====
  wire dst3_n, dst4_n;
  wire [7:0] d0, d1, d2, d3;
  hc238 u_d0 (.A(dst[0]), .B(dst[1]), .C(dst[2]), .E1_n(dst[3]), .E2_n(dst[4]), .E3(1'b1), .Y(d0));   // bestemmingen 0..7
  hc238 u_d1 (.A(dst[0]), .B(dst[1]), .C(dst[2]), .E1_n(dst3_n),  .E2_n(dst[4]), .E3(1'b1), .Y(d1));   //             8..15
  hc238 u_d2 (.A(dst[0]), .B(dst[1]), .C(dst[2]), .E1_n(dst[3]),  .E2_n(dst4_n), .E3(1'b1), .Y(d2));   //            16..23
  hc238 u_d3 (.A(dst[0]), .B(dst[1]), .C(dst[2]), .E1_n(dst3_n),  .E2_n(dst4_n), .E3(1'b1), .Y(d3));   //            24..31
  wire l_r0 = d0[1], l_r1 = d0[2], l_r2 = d0[3], l_r3 = d0[4], l_op = d0[5], l_add = d0[6], l_sub = d0[7];
  wire l_and = d1[0], l_or = d1[1], l_xor = d1[2], l_pc = d1[3], l_mar = d1[4], l_mem = d1[5], l_out = d1[6], l_shl = d1[7];
  wire l_adc = d2[0];
  wire l_halt = d3[7];

  // ===== Bronnen: decoders (74HC138, actief laag) =====
  wire src3_n;
  wire [7:0] s0, s1;
  hc138 u_s0 (.A(src[0]), .B(src[1]), .C(src[2]), .E1_n(src[3]), .E2_n(src[4]), .E3(1'b1), .Y_n(s0));   // bronnen 0..7
  hc138 u_s1 (.A(src[0]), .B(src[1]), .C(src[2]), .E1_n(src3_n),  .E2_n(src[4]), .E3(1'b1), .Y_n(s1));   //         8..15

  // ===== Klok- en schrijfpulsen =====
  // e2 = de move mag doorgaan en de machine is niet gehalt;  e = e2 en de tweede helft van de cyclus (phi)
  wire phi, e2, e, p_r0, p_r1, p_r2, p_r3, p_op, p_mar, p_out, p_mem, p_pc_level, halt_d, is_trig;
  wire adcc, c_term_add, c_term_shl, use_add, use_add_t, we_mem_n, cin, c_mid, c_add;
  // e2 = de move mag doorgaan (guard), de machine is niet gehalt en er is geen reset actief.
  // De reset moet meetellen: terwijl hij loslaat of aanstaat zakken de vlaggen en 'halted' met verschillende vertragingen,
  // wat anders korte valse schrijfpulsen geeft.
  wire e2_unused1, e2_unused2, g1_unused;
  hc11 u_e2 (.A({1'b1, 1'b1, go}), .B({1'b1, 1'b1, halted_n}), .C({1'b1, 1'b1, rst_n}), .Y({e2_unused2, e2_unused1, e2}));
  hc08 u_g1 (.A({l_r1, l_r0, phi, 1'b0}), .B({e, e, e2, 1'b0}), .Y({p_r1, p_r0, e, g1_unused}));

  hc08 u_g2 (.A({l_mar, l_op, l_r3, l_r2}), .B({e, e, e, e}), .Y({p_mar, p_op, p_r3, p_r2}));
  hc08 u_g3 (.A({is_trig, l_pc, l_mem, l_out}), .B({e, e2, e, e}), .Y({res_clk, p_pc_level, p_mem, p_out}));
  hc08 u_g4 (.A({l_shl, use_add, l_adc, l_halt}), .B({bus[7], c_add, cf, e2}), .Y({c_term_shl, c_term_add, adcc, halt_d}));

  // ===== Inverters =====
  wire oe_add_n, oe_and_n, oe_or_n, oe_xor_n, oe_shl_n, inv2_unused;
  hc04 u_inv1 (.A({p_mem, p_pc_level, src[3], dst[4], dst[3], clk}), .Y({we_mem_n, load_pc_n, src3_n, dst4_n, dst3_n, phi}));
  hc04 u_inv2 (.A({l_shl, l_xor, l_or, l_and, use_add, 1'b0}), .Y({oe_shl_n, oe_xor_n, oe_or_n, oe_and_n, oe_add_n, inv2_unused}));

  // ===== Registers op de bus (74HC574) =====
  wire [7:0] op_q, mar_q, res_q, out_q;
  hc574 u_r0  (.D(bus), .CLK(p_r0),  .OE_n(s0[1]), .Q(bus));
  hc574 u_r1  (.D(bus), .CLK(p_r1),  .OE_n(s0[2]), .Q(bus));
  hc574 u_r2  (.D(bus), .CLK(p_r2),  .OE_n(s0[3]), .Q(bus));
  hc574 u_r3  (.D(bus), .CLK(p_r3),  .OE_n(s0[4]), .Q(bus));
  hc574 u_op  (.D(bus), .CLK(p_op),  .OE_n(1'b0),  .Q(op_q));       // operand van de rekeneenheid
  hc574 u_mar (.D(bus), .CLK(p_mar), .OE_n(1'b0),  .Q(mar_q));      // geheugenadres
  hc574 u_out (.D(bus), .CLK(p_out), .OE_n(1'b0),  .Q(out_q));      // uitgangspoort
  hc574 u_res (.D(rbus), .CLK(res_clk), .OE_n(1'b0), .Q(res_q));    // resultaat van de rekeneenheid
  assign out_port = out_q;

  // ===== Overige bronnen op de bus =====
  hc244 u_imm   (.A(rom_lo),                .OE_n(s0[0]), .Y(bus));    // constante uit de instructie
  hc244 u_resb  (.A(res_q),                 .OE_n(s0[5]), .Y(bus));    // RES
  hc244 u_reshr (.A({1'b0, res_q[7:1]}),    .OE_n(s0[6]), .Y(bus));    // RESHR
  hc240 u_resn  (.A(res_q),                 .OE_n(s0[7]), .Y(bus));    // RESNOT (inverterende buffer)
  sram62256 u_ram (.A(mar_q), .CE_n(1'b0), .OE_n(s1[0]), .WE_n(we_mem_n), .DQ(bus));     // MEM (lezen en schrijven)
  hc244 u_in    (.A(in_port),               .OE_n(s1[1]), .Y(bus));    // IN
  wire [7:0] pc2; wire pc2c;
  hc283 u_pc2_lo (.A(pc[3:0]), .B(4'b0010), .C0(1'b0), .S(pc2[3:0]), .C4(pc2c));
  hc283 u_pc2_hi (.A(pc[7:4]), .B(4'b0000), .C0(pc2c), .S(pc2[7:4]), .C4());
  hc244 u_pc2   (.A(pc2),                   .OE_n(s1[2]), .Y(bus));    // PC2 = PC + 2
  hc244 u_flags (.A({5'b00000, nf, cf, zf}), .OE_n(s1[3]), .Y(bus));   // FLAGS

  // ===== De rekeneenheid =====
  wire [7:0] bx, sum, and8, or8, xor8;
  hc32 u_o1 (.A({c_term_add, l_sub, use_add_t, l_add}), .B({c_term_shl, adcc, l_adc, l_sub}), .Y({c_next, cin, use_add, use_add_t}));
  // (use_add_t = l_add | l_sub  — de vierde poort; use_add = use_add_t | l_adc; cin = l_sub | adcc; c_next = c_term_add | c_term_shl)
  hc86 u_bx_lo (.A(bus[3:0]), .B({4{l_sub}}), .Y(bx[3:0]));    // bij aftrekken de bus omkeren
  hc86 u_bx_hi (.A(bus[7:4]), .B({4{l_sub}}), .Y(bx[7:4]));
  hc283 u_add_lo (.A(op_q[3:0]), .B(bx[3:0]), .C0(cin),   .S(sum[3:0]), .C4(c_mid));
  hc283 u_add_hi (.A(op_q[7:4]), .B(bx[7:4]), .C0(c_mid), .S(sum[7:4]), .C4(c_add));
  hc08 u_and_lo (.A(op_q[3:0]), .B(bus[3:0]), .Y(and8[3:0]));
  hc08 u_and_hi (.A(op_q[7:4]), .B(bus[7:4]), .Y(and8[7:4]));
  hc32 u_or_lo  (.A(op_q[3:0]), .B(bus[3:0]), .Y(or8[3:0]));
  hc32 u_or_hi  (.A(op_q[7:4]), .B(bus[7:4]), .Y(or8[7:4]));
  hc86 u_xor_lo (.A(op_q[3:0]), .B(bus[3:0]), .Y(xor8[3:0]));
  hc86 u_xor_hi (.A(op_q[7:4]), .B(bus[7:4]), .Y(xor8[7:4]));
  hc244 u_rb_add (.A(sum),               .OE_n(oe_add_n), .Y(rbus));
  hc244 u_rb_and (.A(and8),              .OE_n(oe_and_n), .Y(rbus));
  hc244 u_rb_or  (.A(or8),               .OE_n(oe_or_n),  .Y(rbus));
  hc244 u_rb_xor (.A(xor8),              .OE_n(oe_xor_n), .Y(rbus));
  hc244 u_rb_shl (.A({bus[6:0], 1'b0}),  .OE_n(oe_shl_n), .Y(rbus));

  // is_trig: is de bestemming een rekentrigger?  z_next: is het resultaat nul?
  hc4078 u_trig (.A({1'b0, l_shl, l_xor, l_or, l_and, l_adc, l_sub, l_add}), .Y(), .J(is_trig));
  hc4078 u_zero (.A(rbus), .Y(z_next), .J());
  assign n_next = rbus[7];

  // ===== Halt: de flipflop neemt de stop-aanvraag over op de stijgende klokflank en houdt hem vast =====
  // Let op de OR met de eigen uitgang: zonder die terugkoppeling zou 'halted' meteen weer 0 worden,
  // want zodra de machine gehalt is, valt 'e2' (en dus halt_d) weg.
  wire halt_hold, o2_u1, o2_u2, o2_u3;
  hc32 u_o2 (.A({3'b000, halt_d}), .B({3'b000, halted}), .Y({o2_u3, o2_u2, o2_u1, halt_hold}));
  hc74 u_halt (.D(halt_hold), .CLK(clk), .CLR_n(rst_n), .SET_n(1'b1), .Q(halted), .Qn(halted_n));
endmodule
