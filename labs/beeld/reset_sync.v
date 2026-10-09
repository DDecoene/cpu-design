// Een reset die asynchroon begint en synchroon eindigt: twee flipflops (week 6). Elk klokdomein krijgt er een.
module reset_sync(
  input  clk,
  input  rst_n_in,
  output rst_n_out
);
  reg [1:0] s = 2'b00;
  always @(posedge clk or negedge rst_n_in)
    if (!rst_n_in) s <= 2'b00;
    else           s <= {s[0], 1'b1};
  assign rst_n_out = s[1];
endmodule
