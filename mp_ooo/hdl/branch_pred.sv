module branch_pred 
import rv32i_types::*;
(
    input   logic   [31:0]  pc,
    output  logic           prediction
);
    logic   [31:0]  pc_dummy;

    assign pc_dummy = pc;
    assign prediction = 1'b0;

endmodule   : branch_pred