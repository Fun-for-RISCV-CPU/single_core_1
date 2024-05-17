// first stage in fetch unit
// request to mem/cache and also where branch pred will start
module fetch_1
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               branch_mispredict,
    input   logic   [31:0]      branch_target,
    input   logic               imem_stall,
    input   fetch_reg_1_t       fetch_1_reg,
    output  fetch_reg_1_t       fetch_1_reg_next,
    output  logic [31:0]        imem_addr,
    output  logic [3:0]         imem_rmask
);
    logic [31:0] pc;
    logic [31:0] pc_next;
    logic valid;

    logic [31:0] btb_address;
    logic prediction;

    branch_pred branch_pred_inst(
        .pc(pc),
        .prediction(prediction)
    );

    btb btb_inst(
        .pc(pc),
        .pred_address(btb_address)
    );

    always_ff @ (posedge clk) begin
        if (rst) begin
            pc <= 'h60000000;
        end
        else begin
            pc <= pc_next;
        end
        
    end

    always_comb begin
        valid = 1'b0;
        if (rst) begin
            pc_next = 'x;
            imem_addr = 'x;
            imem_rmask = 'x;
            fetch_1_reg_next.valid = valid;
            fetch_1_reg_next.pc = 'x;
        end
        // stall logic when imem resp not high or queues are full
        else if (imem_stall) begin
            pc_next = pc;
            imem_addr = pc - 'd4;
            imem_rmask = 4'b1111;
            fetch_1_reg_next =  fetch_1_reg;
        end 
        else begin 
            valid = 1'b1;
            // Mux between pc and predicted from BTB and branch predictor
            if (prediction == taken) begin
                imem_addr = pc;
                imem_rmask = 4'b1111;
                pc_next = btb_address;
            end else if (branch_mispredict) begin
                pc_next = branch_target + 'd4;
                imem_addr = branch_target;
                imem_rmask = 4'b1111;
            end else begin // predicts branch not taken
                imem_addr = pc;
                imem_rmask = 4'b1111;
                pc_next = pc + 'd4;
            end
            
            // // Mux two
            // // Switch to branch target is mis predict occurs
            // // Otherwise keep from above mux 
            // // TODO: Add another case when RAS implemented
            // if (branch_mispredict) begin
            //     pc_next = branch_target + 'd4;
            //     imem_addr = branch_target;
            //     imem_rmask = 4'b1111;
            // end

            fetch_1_reg_next.pc = pc;
            fetch_1_reg_next.valid = valid;
        end
    end

endmodule : fetch_1