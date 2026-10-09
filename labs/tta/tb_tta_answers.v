module tb_tta_answers;
  reg clk = 0, rst_n = 0;
  wire [7:0] out_port;
  wire out_valid, halted;
  integer fouten = 0, cycli = 0, n = 0;
  reg [7:0] v [0:15];
  tta #("answers.hex", 1) dut(.clk(clk), .rst_n(rst_n), .in_port(8'd0), .out_port(out_port), .out_valid(out_valid), .halted(halted));
  always #5 clk = ~clk;
  always @(posedge clk) if (out_valid) begin v[n] = out_port; n = n + 1; end
  initial begin
    #22 rst_n = 1;
    while (!halted && cycli < 10000) begin @(negedge clk); cycli = cycli + 1; end
    @(negedge clk);
    if (n !== 4 || v[0] !== 8'd200 || v[1] !== 8'd9 || v[2] !== 8'd250 || v[3] !== 8'd91) begin
      fouten = fouten + 1; $display("FAIL: %0d uitvoerwaarden: %0d %0d %0d %0d", n, v[0], v[1], v[2], v[3]);
    end
    if (fouten == 0) $display("PASS: max met guard, negatie en rechtsschuiven met RESHR kloppen");
    $finish;
  end
endmodule
