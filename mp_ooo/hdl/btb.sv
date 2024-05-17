module btb 
(
    input   logic   [31:0]  pc,
    output  logic   [31:0]  pred_address
);
    logic   [31:0]  pc_dummy;

    assign pc_dummy = pc;
    assign pred_address = 'x;

endmodule : btb