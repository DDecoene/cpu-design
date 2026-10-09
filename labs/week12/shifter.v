// Barrel shifter. mode: 00 LSL, 01 LSR, 10 ASR, 11 ROR.
module shifter #(parameter W = 8, parameter SW = 3) (
  input  [W-1:0]  a,
  input  [SW-1:0] sh,
  input  [1:0]    mode,
  output [W-1:0]  y
);
  wire [W-1:0] st [0:SW];          // st[k] is het tussenresultaat voor trap k
  assign st[0] = a;

  genvar k;
  generate
    for (k = 0; k < SW; k = k + 1) begin : stage
      localparam N = 1 << k;       // deze trap schuift N plaatsen
      wire [W-1:0] x   = st[k];
      wire [W-1:0] lsl = x << N;
      wire [W-1:0] lsr = x >> N;
      wire [W-1:0] asr = $signed(x) >>> N;
      wire [W-1:0] ror = (x >> N) | (x << (W - N));
      wire [W-1:0] r   = (mode == 2'b00) ? lsl :
                         (mode == 2'b01) ? lsr :
                         (mode == 2'b10) ? asr : ror;
      assign st[k+1] = sh[k] ? r : x;
    end
  endgenerate

  assign y = st[SW];
endmodule
