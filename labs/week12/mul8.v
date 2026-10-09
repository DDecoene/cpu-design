// 8x8 -> 16 bits, zonder teken, 8 cycli.
module mul8(
  input             clk,
  input             rst_n,
  input             start,
  input      [7:0]  a,
  input      [7:0]  b,
  output reg [15:0] p,
  output reg        done
);
  reg [15:0] mcand;     // vermenigvuldigtal, schuift naar links
  reg [7:0]  mplier;    // vermenigvuldiger, schuift naar rechts
  reg [3:0]  cnt;
  reg        busy;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      p <= 0; done <= 0; busy <= 0; mcand <= 0; mplier <= 0; cnt <= 0;
    end else if (!busy) begin
      if (start) begin
        mcand <= {8'b0, a};  mplier <= b;  p <= 0;  cnt <= 0;
        busy <= 1;  done <= 0;
      end
    end else begin
      if (mplier[0]) p <= p + mcand;
      mcand  <= mcand << 1;
      mplier <= mplier >> 1;
      cnt    <= cnt + 1'b1;
      if (cnt == 4'd7) begin busy <= 0; done <= 1; end
    end
endmodule
