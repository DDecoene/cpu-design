module tb_bouwstenen;
  reg  [7:0] a, b;
  reg        cin;
  wire [7:0] s;
  wire       cout;
  reg  [7:0] p_in;
  wire [2:0] p_y;
  wire       p_valid;
  wire       y_even, y_odd;
  integer i, j, k, fouten = 0;
  reg [8:0] verwacht;
  reg [2:0] ref_y;

  addn #(8) adder(a, b, cin, s, cout);
  prio_enc8 enc(p_in, p_y, p_valid);
  parity_demo par(a, y_even, y_odd);

  initial begin
    // 8-bit opteller: 2000 willekeurige gevallen plus de hoeken.
    for (i = 0; i < 2000; i = i + 1) begin
      a = $random; b = $random; cin = $random; #1;
      verwacht = a + b + cin;
      if ({cout, s} !== verwacht) begin fouten = fouten + 1; $display("FAIL add: %0d+%0d+%0d", a, b, cin); end
    end
    a = 8'hFF; b = 8'h01; cin = 0; #1;
    if ({cout, s} !== 9'h100) begin fouten = fouten + 1; $display("FAIL add: 255+1"); end

    // Prioriteitsencoder: alle 256 invoeren tegen een referentie.
    for (j = 0; j < 256; j = j + 1) begin
      p_in = j[7:0]; #1;
      ref_y = 0;
      for (k = 0; k < 8; k = k + 1) if (p_in[k]) ref_y = k[2:0];
      if (p_y !== ref_y || p_valid !== (j != 0)) begin
        fouten = fouten + 1; $display("FAIL prio bij %b: y=%0d valid=%b", p_in, p_y, p_valid);
      end
    end

    // Pariteit
    a = 8'b0000_0111; #1; if (y_odd !== 1'b1) begin fouten = fouten + 1; $display("FAIL pariteit 7"); end
    a = 8'b0000_0011; #1; if (y_odd !== 1'b0) begin fouten = fouten + 1; $display("FAIL pariteit 3"); end

    if (fouten == 0) $display("PASS: addn, prio_enc8 en parity_demo kloppen");
    $finish;
  end
endmodule
