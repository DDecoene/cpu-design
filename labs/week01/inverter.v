// Een inverter: de uitgang is het omgekeerde van de ingang.
module inverter(input a, output y);
  assign y = ~a;
endmodule
