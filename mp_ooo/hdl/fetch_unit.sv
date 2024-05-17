module fetch_unit
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               rob_full,
    input   logic               branch_mispredict,
    input   logic [31:0]        branch_target,
    input   logic               imem_resp,
    input   logic [31:0]        imem_rdata,
    input   logic               reservation_full,
    output  logic [31:0]        imem_addr,
    output  logic [3:0]         imem_rmask,
    output  logic               valid_inst,
    output  logic [63:0]        inst_out
);
    
    logic           imem_stall;
    fetch_reg_1_t   fetch_1_reg, fetch_1_reg_next;

    always_ff @(posedge clk) begin
        fetch_1_reg <= fetch_1_reg_next;
    end

    fetch_1 fetch_stage_1(
        .clk(clk),
        .rst(rst),
        .branch_mispredict(branch_mispredict),
        .branch_target(branch_target),
        .imem_stall(imem_stall),
        .fetch_1_reg(fetch_1_reg),
        .fetch_1_reg_next(fetch_1_reg_next),
        .imem_addr(imem_addr),
        .imem_rmask(imem_rmask)
    );


    fetch_2 fetch_stage_2(
        .clk(clk),
        .rst(rst),
        .imem_resp(imem_resp),
        .inst_in(imem_rdata),
        .fetch_1_reg(fetch_1_reg),
        .valid_inst(valid_inst),
        .reservation_full(reservation_full),
        .inst_out(inst_out),
        .imem_stall(imem_stall),
        .rob_full(rob_full)
    );
    
    

endmodule : fetch_unit