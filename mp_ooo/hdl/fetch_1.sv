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
    output  logic [3:0]         imem_rmask,
    input    logic [31:0] pcout_at_fetch,
    input logic branch_pred_fetch,
    output logic    valid_first_inst,
    input logic     second_instruction_valid,
    output logic [31:0] pc_at_fetch,
    input logic queue_full
);
    logic [31:0] pc;
    logic [31:0] pc_next, pc_delayed, pc_next_delayed, pcout_at_fetch_delayed, second_pcout_delayed;
    logic valid;
	logic [31:0] pred_address;
    logic branch_pred_delayed;
    logic valid_first_delayed;

   // logic [31:0] btb_address;
   // logic prediction;
   // logic fetch_to_btb_bus pc_at_fetch;
   // logic btb_to_fetch_bus pc_at_decode;

    //branch_pred branch_pred_inst(
      //  .pc(pc),
        //.prediction(prediction)
    //);


   // btb btb_inst(
     //   .pc(pc),
       // .pred_address(btb_address)
    //);

    always_ff @ (posedge clk) begin
        if (rst) begin
            pc <= 'h60000000;
            branch_pred_delayed <= 'x;
            pc_delayed <= 'x;
            pc_next_delayed <= 'x;
            valid_first_inst <= 1'b1;
	        valid_first_delayed <= 'x;
	        pcout_at_fetch_delayed <= 'x;
	        second_pcout_delayed = 'x;
        end
        else begin
            branch_pred_delayed <= branch_pred_fetch;
	    //valid_first_delayed <= valid_first_inst;
	    second_pcout_delayed = pcout_at_fetch;
            pc <= pc_next;
            valid_first_delayed <= valid_first_inst;
             if(!imem_stall) begin
             pc_delayed <= pc;
             pc_next_delayed <= pc_next;
	         pcout_at_fetch_delayed <= pcout_at_fetch;
	         valid_first_delayed <= valid_first_inst;
             end
             else begin
             pc_delayed <= pc_delayed;
             pc_next_delayed <= pc_next_delayed;
             pcout_at_fetch_delayed <= pcout_at_fetch_delayed;
	         valid_first_delayed <= valid_first_delayed;
             end

            // Check if misaligned if so then first inst is not valid
            if((branch_target[2] == 1'b0) && branch_mispredict) begin
                valid_first_inst <= 1'b1;
            end
            else if ((branch_target[2] && branch_mispredict) || (pcout_at_fetch[2] && !branch_mispredict && !imem_stall)) begin
                valid_first_inst <= 1'b0;
            end
            else if(imem_stall && (branch_pred_delayed) && !queue_full) begin
                valid_first_inst <= pcout_at_fetch_delayed[2] ? 1'b0:1'b1;
            end
            else if(imem_stall && (!branch_pred_delayed) && !queue_full) begin
                valid_first_inst <= valid_first_inst;
            end
            else if(imem_stall && (!branch_pred_delayed) && queue_full) begin
                valid_first_inst <= valid_first_inst;
            end
            else if(imem_stall && (branch_pred_delayed) && queue_full) begin
                valid_first_inst <= valid_first_inst;
            end
	        else begin
                valid_first_inst <= 1'b1;
            end
        end
        
    end
	
    always_comb begin
        valid = 1'b0;
		pc_at_fetch = {pc[31:3], 3'b000};
		pred_address = pcout_at_fetch;
		
        // // Check if misaligned if so then first inst is not valid
        // if ((branch_target[2] && branch_mispredict) || (pcout_at_fetch[2] && !branch_mispredict)) begin
        //     valid_first_inst_next = 1'b0;
        // end else if (imem_stall) begin
        //     valid_first_inst_next = valid_first_inst_delayed;
        // end else begin
        //     valid_first_inst_next = 1'b1;
        // end

        if (rst) begin
            pc_next = 'x;
            imem_addr = 'x;
            imem_rmask = 'x;
            fetch_1_reg_next.valid = valid;
            fetch_1_reg_next.pc = 'x;
            fetch_1_reg_next.branch_pred[0] = 1'b0;
            fetch_1_reg_next.branch_pred[1] = 1'b0;
            
        end
        // stall logic when imem resp not high or queues are full
        else if (imem_stall && !branch_mispredict && !branch_pred_delayed && !queue_full) begin
            pc_next = pc;
            imem_addr = ( pc - 'd8);
            imem_rmask = 4'b1111;
            fetch_1_reg_next =  fetch_1_reg;        
        end 
        
         else if (imem_stall && !branch_mispredict && (branch_pred_delayed || queue_full) ) begin
            pc_next = pc;
            imem_addr = pc_delayed;
            imem_rmask = 4'b1111;
            fetch_1_reg_next =  fetch_1_reg;

        end 
        
        
        
        else begin 
            valid = 1'b1;
            // Mux between pc and predicted from BTB and branch predictor
                imem_addr = pc;
                imem_rmask = 4'b1111;
                pc_next = pcout_at_fetch;
             if (branch_mispredict) begin

                    pc_next = {branch_target[31:3], 3'b000};
                    imem_addr = {branch_target[31:3], 3'b000};
                    imem_rmask = 4'b1111;
                    valid = 1'b1;

            end  
            fetch_1_reg_next.pc = imem_addr;

            if (second_instruction_valid && branch_pred_fetch) begin
                fetch_1_reg_next.branch_pred[0] = 1'b0;
            end else begin
                fetch_1_reg_next.branch_pred[0] = branch_pred_fetch;
            end
            fetch_1_reg_next.branch_pred[1] = branch_pred_fetch;
            
            // Set valids according to alignment
            if (valid_first_inst) begin
                fetch_1_reg_next.valid[0] = 1'b1;
                fetch_1_reg_next.valid[1] = second_instruction_valid;
            // end else if (branch_mispredict) begin
            //     fetch_1_reg_next.valid[0] = 1'b0;
            //     fetch_1_reg_next.valid[1] = 1'b1; end
            end else begin
                fetch_1_reg_next.valid[0] = 1'b0;
                fetch_1_reg_next.valid[1] = 1'b1;
            end
        end
    end

endmodule : fetch_1
