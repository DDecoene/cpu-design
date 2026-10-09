module half_adder(input a, input b, output s, output c);
  assign s = a ^ b;
  assign c = a & b;
endmodule

module full_adder(input a, input b, input cin, output s, output cout);
  wire s1, c1, c2;
  half_adder h1(a, b, s1, c1);
  half_adder h2(s1, cin, s, c2);
  assign cout = c1 | c2;
endmodule

// 4-bit ripple-carry opteller: vier full adders, de carry "rimpelt" van rechts naar links.
module adder4(
  input  [3:0] a,
  input  [3:0] b,
  input        cin,
  output [3:0] s,
  output       cout
);
  wire c1, c2, c3;
  full_adder f0(a[0], b[0], cin, s[0], c1);
  full_adder f1(a[1], b[1], c1,  s[1], c2);
  full_adder f2(a[2], b[2], c2,  s[2], c3);
  full_adder f3(a[3], b[3], c3,  s[3], cout);
endmodule
