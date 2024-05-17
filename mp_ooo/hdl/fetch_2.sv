 // second stage in fetch unit
// Logic for pushing and popping queue 
// Based on reservation full, queue full or empty and imem response
module fetch_2
import rv32i_types::*;
(
    input   logic                   clk,
    input   logic                   rst,
    input   logic                   branch_mispredict,
    input   logic                   rob_full,
    input   logic                   imem_resp,
    input   logic   [31:0]          inst_in,
    input   logic                   reservation_full,
    input   fetch_reg_1_t           fetch_1_reg,
    output  logic   [63:0]          inst_out,
    output  logic                   valid_inst, 
    output  logic                   imem_stall
);  

    logic [1:0]     action;
    logic           empty;
    logic           queue_full;
    logic           valid_bit;
    logic [64:0]    queue_packet;

    instruction_q instruction_q(
        .clk(clk),
        .rst(rst),
        .branch_mispredict(branch_mispredict),
        .inst_in({valid_bit, fetch_1_reg.pc, inst_in}),
        .action(action),
        .empty(empty),
        .full(queue_full),
        .inst_out(queue_packet)
    );

    assign valid_inst = queue_packet[64];
    assign inst_out   = queue_packet[63:0];

    always_comb begin

        // stall pc when imem_resp = 0
        // cases for queue
        // 1: queue is empty
        // subcase 1: imem_resp high -> push instruction
        // subcase 2: imem resp low -> do nothing
        // 2: queue is full
        // subcase 1: reservation full
        // subcase 2: imem resp high -> push and pop
        // subcase 3: imem_resp low -> pop
        // 2: queue is not empty or full
        // subcase 1: reservation full -> push
        // subcase 1: imem_resp high -> push and pop
        // subcase 2: imem_resp low -> pop
        imem_stall = 1'b0;
        valid_bit = 1'b0;
        if (!imem_resp && fetch_1_reg.valid) begin
            imem_stall = 1'b1;
        end
        
        if (!fetch_1_reg.valid) begin
            action = none;
        end else if (empty) begin
            if (imem_resp) begin
                action = push;
                valid_bit = 1'b1;
            end else begin
                action = none;
            end
        end else if (queue_full) begin
            if (reservation_full || rob_full) begin
                // stall stages 
                //(needs work if imem resp is high and cannot push or pop the current instruction needs to be stored somwhere)
                // instruction in this case is lost
                imem_stall = 1'b1;
                action = none;
            end else if (imem_resp) begin
                action = push_pop;
                valid_bit = 1'b1;
            end else begin
                action = pop;
            end
        end else begin
            if (reservation_full || rob_full && imem_resp) begin
                if (imem_resp) begin
                    action = push;
                    valid_bit = 1'b1;
                end
                else begin
                    action = none;
                end
            end else if (imem_resp) begin
                action = push_pop;
                valid_bit = 1'b1;
            end else begin
                action = pop;
            end
        end 


    end

endmodule : fetch_2