// FILE: week07/seqdet.v
module seqdet(
  input  clk,
  input  rst_n,
  input  in,
  output detected
);
  localparam S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, S4 = 3'd4;

  reg [2:0] state, next;

  // Blok 1: het toestandsregister (sequentieel).
  always @(posedge clk or negedge rst_n)
    if (!rst_n) state <= S0;
    else        state <= next;

  // Blok 2: volgende-toestandslogica (combinatorisch).
  always @* begin
    next = S0;                       // standaardwaarde: voorkomt latches
    case (state)
      S0: next = in ? S1 : S0;
      S1: next = in ? S1 : S2;
      S2: next = in ? S3 : S0;
      S3: next = in ? S4 : S2;
      S4: next = in ? S1 : S2;
      default: next = S0;            // ongeldige toestanden vangen we op
    endcase
  end

  // Blok 3: uitgangslogica (Moore: alleen van de toestand afhankelijk).
  assign detected = (state == S4);
endmodule
