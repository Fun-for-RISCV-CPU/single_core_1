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
    output logic [31:0] pc_at_fetch,
    input logic queue_full
);
    logic [31:0] pc;
    logic [31:0] pc_next, pc_delayed, pc_next_delayed;
    logic valid;
	logic [31:0] pred_address;
 logic branch_pred_delayed;

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
        end
        else begin
            branch_pred_delayed <= branch_pred_fetch;
            pc <= pc_next;
            
             if(!imem_stall) begin
             pc_delayed <= pc;
             pc_next_delayed <= pc_next;
             end
             else begin
             pc_delayed <= pc_delayed;
             pc_next_delayed <= pc_next_delayed;
             
             end
        end
        
    end
	
	

    always_comb begin
        valid = 1'b0;
		pc_at_fetch = pc;
		pred_address = pcout_at_fetch;
		
        if (rst) begin
            pc_next = 'x;
            imem_addr = 'x;
            imem_rmask = 'x;
            fetch_1_reg_next.valid = valid;
            fetch_1_reg_next.pc = 'x;
            fetch_1_reg_next.branch_pred = 1'b0;
            
        end
        // stall logic when imem resp not high or queues are full
        else if (imem_stall && !branch_mispredict && !branch_pred_delayed && !queue_full) begin
            pc_next = pc;
            imem_addr = ( pc - 'd4);
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

                    pc_next = branch_target;
                    imem_addr = branch_target;
                    imem_rmask = 4'b1111;
                    valid = 1'b1;

            end  
            fetch_1_reg_next.pc = imem_addr;
            fetch_1_reg_next.valid = valid;
            fetch_1_reg_next.branch_pred = branch_pred_fetch;
        end
    end

endmodule : fetch_1