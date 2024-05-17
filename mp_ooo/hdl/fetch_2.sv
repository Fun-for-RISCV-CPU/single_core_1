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
    input   logic   [SS_DISPATCH_WIDTH*32-1:0]          inst_in,
    input   logic                   reservation_full,
    input   fetch_reg_1_t           fetch_1_reg,
    output  iqueue_entry_t   [SS_DISPATCH_WIDTH-1:0]    inst_out,
    output  logic                   imem_stall,
    output  logic                   queue_full,
    output  logic [1:0][15:0]       age
    );  

    logic [1:0]     action;
    logic           empty;
    logic [SS_DISPATCH_WIDTH-1:0]          valid_bit;
    logic [SS_DISPATCH_WIDTH-1:0]          valid_bit_mask;
    logic valid_inst;
    // logic [65:0]    queue_packet;
    iqueue_entry_t  [SS_DISPATCH_WIDTH-1:0] enqueue_inst;

    logic [SS_DISPATCH_WIDTH-1:0][31:0] inst_split;
    logic [SS_DISPATCH_WIDTH-1:0][31:0] pc_split;

    instruction_q instruction_q(
        .clk(clk),
        .rst(rst),
        .branch_mispredict(branch_mispredict),
        .inst_in(enqueue_inst),
        //.inst_in({valid_bit,  fetch_1_reg.branch_pred, fetch_1_reg.pc, inst_in}),
        .action(action),
        .empty(empty),
        .full(queue_full),
        .inst_out(inst_out)
    );

    assign inst_split[0] = inst_in[31:0];
    assign inst_split[1] = inst_in[63:32];
    assign pc_split[0] = {fetch_1_reg.pc[31:3], 3'b000};
    assign pc_split[1] = {fetch_1_reg.pc[31:3], 3'b100};

    // Variables for load
    logic   [15:0]  age_next;

    assign age_next = age[0] + 2'b10;

    always_ff @(posedge clk) begin
        if (rst || branch_mispredict) begin
            age[0] <= '0;
            age[1] <= '0;
        end
        else begin
            age[0] <= age_next;
            age[1] <= age_next + 1'b1;
        end
    end

    always_comb begin
        // Values for enqueue
        // for (int i=0; i < SS_DISPATCH_WIDTH; i++) begin
        //     enqueue_inst[i].valid = valid_bit[i];
        //     enqueue_inst[i].branch_pred = fetch_1_reg.branch_pred[i];
        //     enqueue_inst[i].inst = inst_split[i];
        //     // Set PC based on index in fetch (assuming 2 wide fetch)
        //     enqueue_inst[i].pc = pc_split[i];
        // end
        
        // Swap if only the second position is valid


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
        valid_bit = 2'b00;
        if (fetch_1_reg.pc[2]) begin
            valid_bit_mask = 2'b01;
        end else begin
            valid_bit_mask = {fetch_1_reg.valid[1], fetch_1_reg.valid[0]};
        end
        
        valid_inst = fetch_1_reg.valid[0] || fetch_1_reg.valid[1];
        if (!imem_resp && valid_inst) begin
            imem_stall = 1'b1;
        end
        
        if (!valid_inst) begin
            action = none;
        end else if (empty) begin
            if (imem_resp) begin
                action = push;
                valid_bit = valid_bit_mask;
            end else begin
                action = none;
            end
        end else if (queue_full) begin
            if (reservation_full || rob_full) begin
                // stall stages 
                //(needs work if imem resp is high and cannot push or pop the current instruction needs to be stored somwhere)
                // instruction in this case is lost
                imem_stall = 1'b1; // Ask michael about the intention here, was lint error
                action = none;
            end else if (imem_resp) begin
                action = push_pop;
                valid_bit = valid_bit_mask;
            end else begin
                action = pop;
            end
        end else begin
            if (reservation_full || rob_full) begin
                if (imem_resp) begin
                    action = push;
                    valid_bit = valid_bit_mask;
                end
                else begin
                    action = none;
                end
            end else if (imem_resp) begin
                action = push_pop;
                valid_bit = valid_bit_mask;
            end else begin
                action = pop;
            end
        end 
        
        if (fetch_1_reg.valid == 2'b10) begin
            enqueue_inst[0].valid = 1'b1;
            enqueue_inst[0].branch_pred = fetch_1_reg.branch_pred[1];
            enqueue_inst[0].inst = inst_split[1];
            enqueue_inst[0].pc = pc_split[1];

            enqueue_inst[1].valid = 1'b0;
            enqueue_inst[1].branch_pred = 'x;
            enqueue_inst[1].inst = 'x;
            enqueue_inst[1].pc = 'x;
        end 
        // Normal (aligned) case valid = 00 01 or 11
        else begin
            enqueue_inst[0].valid = valid_bit[0];
            enqueue_inst[0].branch_pred = fetch_1_reg.branch_pred[0];
            enqueue_inst[0].inst = inst_split[0];
            enqueue_inst[0].pc = pc_split[0];

            enqueue_inst[1].valid = valid_bit[1];
            enqueue_inst[1].branch_pred = fetch_1_reg.branch_pred[1];
            enqueue_inst[1].inst = inst_split[1];
            enqueue_inst[1].pc = pc_split[1];
        end

    end

endmodule : fetch_2