// FILE: week09/funcs.v
module parity_demo(input [7:0] x, output y_even, output y_odd);
  function automatic parity(input [7:0] v);
    parity = ^v;                         // 1 als het aantal enen oneven is
  endfunction
  assign y_odd  = parity(x);
  assign y_even = ~parity(x);
endmodule
