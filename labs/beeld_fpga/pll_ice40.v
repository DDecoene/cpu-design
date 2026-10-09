// De pixelklok uit de 12 MHz van het bord, met de PLL van de iCE40. De getallen komen van het hulpprogramma icepll:
//   icepll -i 12 -o 25.175   geeft 25,125 MHz (VCO 804 MHz, gedeeld door 32). Dat ligt 0,2 % onder de standaard 25,175 MHz.
// Dit bestand gebruikt een primitief van de chip en kan daarom niet in Icarus Verilog gesimuleerd worden.
module pll_ice40(
  input  clk_in,
  output clk_out,
  output locked
);
  SB_PLL40_CORE #(
    .FEEDBACK_PATH("SIMPLE"),
    .DIVR(4'b0000),            // referentie: 12 MHz / (DIVR + 1)
    .DIVF(7'b1000010),         // VCO: 12 MHz * (DIVF + 1) = 12 * 67 = 804 MHz
    .DIVQ(3'b101),             // uitgang: VCO / 2^DIVQ = 804 / 32 = 25,125 MHz
    .FILTER_RANGE(3'b001)
  ) pll (
    .REFERENCECLK(clk_in),
    .PLLOUTCORE(clk_out),
    .LOCK(locked),
    .RESETB(1'b1),
    .BYPASS(1'b0)
  );
endmodule
