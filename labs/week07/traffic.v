module traffic #(parameter G = 5, parameter Y = 2) (
  input        clk,
  input        rst_n,
  output reg [1:0] ns,    // 00 rood, 01 geel, 10 groen
  output reg [1:0] ew
);
  localparam NSG = 2'd0, NSY = 2'd1, EWG = 2'd2, EWY = 2'd3;

  reg [1:0] state, next;
  reg [7:0] t;
  wire [7:0] duur = (state == NSG || state == EWG) ? G : Y;
  wire       klaar = (t == duur - 1);

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin state <= NSG; t <= 0; end
    else if (klaar) begin state <= next; t <= 0; end
    else t <= t + 1'b1;

  always @* begin
    case (state)
      NSG: next = NSY;
      NSY: next = EWG;
      EWG: next = EWY;
      default: next = NSG;
    endcase
  end

  always @* begin
    case (state)
      NSG: begin ns = 2'b10; ew = 2'b00; end
      NSY: begin ns = 2'b01; ew = 2'b00; end
      EWG: begin ns = 2'b00; ew = 2'b10; end
      default: begin ns = 2'b00; ew = 2'b01; end
    endcase
  end
endmodule
