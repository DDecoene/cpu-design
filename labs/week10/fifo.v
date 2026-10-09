module fifo #(parameter DW = 8, parameter AW = 3) (
  input               clk,
  input               rst_n,
  input               push,
  input               pop,
  input      [DW-1:0] din,
  output     [DW-1:0] dout,
  output              full,
  output              empty
);
  reg [DW-1:0] mem [0:(1<<AW)-1];
  reg [AW-1:0] wp, rp;
  reg [AW:0]   count;

  assign full  = (count == (1 << AW));
  assign empty = (count == 0);
  assign dout  = mem[rp];

  wire do_push = push && !full;
  wire do_pop  = pop  && !empty;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      wp <= 0; rp <= 0; count <= 0;
    end else begin
      if (do_push) begin mem[wp] <= din; wp <= wp + 1'b1; end
      if (do_pop)  rp <= rp + 1'b1;
      count <= count + do_push - do_pop;
    end
endmodule
