// FILE: week09/blocking.v
// Drie keer hetzelfde idee: een 3-staps vertraging voor een bit.
module pipe_nb(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) begin
    q1 <= d;      // alle drie lezen de OUDE waarden
    q2 <= q1;
    q3 <= q2;
  end
endmodule

// FOUT: met blokkerende toekenningen valt het hele ding in elkaar.
module pipe_bad(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) begin
    q1 = d;       // q1 is meteen d
    q2 = q1;      // dus q2 ook, meteen
    q3 = q2;      // en q3 ook: er is geen vertraging meer
  end
endmodule
