module adder
import rv32i_types::*;
#()
(
    input logic [31:0] a, b,
    output logic [31:0] out
);

assign out = a + b;
endmodule: adder