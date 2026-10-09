// 8-bit (parametrisch) ALU met vlaggen Z, N, C, V.
module alu #(parameter W = 8) (
  input      [W-1:0] a,
  input      [W-1:0] b,
  input      [2:0]   op,
  output reg [W-1:0] y,
  output             z,
  output             n,
  output reg         c,
  output reg         v
);
  localparam ADD = 3'd0, SUB = 3'd1, AND_ = 3'd2, OR_ = 3'd3,
             XOR_ = 3'd4, NOT_ = 3'd5, SHL = 3'd6, SHR = 3'd7;

  // Eén extra bit breed, zodat de carry uit het hoogste bit zichtbaar is.
  wire [W:0] sum  = {1'b0, a} + {1'b0, b};
  wire [W:0] diff = {1'b0, a} + {1'b0, ~b} + 1'b1;     // A - B = A + ~B + 1

  always @* begin
    y = {W{1'b0}};  c = 1'b0;  v = 1'b0;               // standaardwaarden: geen latches
    case (op)
      ADD:  begin
              y = sum[W-1:0];  c = sum[W];
              v = (a[W-1] == b[W-1]) && (y[W-1] != a[W-1]);
            end
      SUB:  begin
              y = diff[W-1:0]; c = diff[W];
              v = (a[W-1] != b[W-1]) && (y[W-1] != a[W-1]);
            end
      AND_: y = a & b;
      OR_:  y = a | b;
      XOR_: y = a ^ b;
      NOT_: y = ~a;
      SHL:  begin y = {a[W-2:0], 1'b0}; c = a[W-1]; end
      SHR:  begin y = {1'b0, a[W-1:1]}; c = a[0];   end
    endcase
  end

  assign z = (y == {W{1'b0}});
  assign n = y[W-1];
endmodule
