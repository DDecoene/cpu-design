module fa(input a, input b, input cin, output s, output cout);
  assign s    = a ^ b ^ cin;
  assign cout = (a & b) | (cin & (a ^ b));
endmodule

module addn #(parameter N = 8) (
  input  [N-1:0] a,
  input  [N-1:0] b,
  input          cin,
  output [N-1:0] s,
  output         cout
);
  wire [N:0] c;
  assign c[0] = cin;
  assign cout = c[N];

  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : gen_bit
      fa f(a[i], b[i], c[i], s[i], c[i+1]);
    end
  endgenerate
endmodule
