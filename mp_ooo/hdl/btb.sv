module btb
import rv32i_types::*;
#(parameter btb_depth = 32, btb_depth_bits = 5)
(
    input   logic   clk,
    input   logic   rst,
    input    logic  [31:0] pc_at_fetch,
    output    logic [31:0] pcout_at_fetch,
    input  rob_to_btb_bus pc_at_commit,
    output  logic  branch_pred_fetch
);

    //btb_entry btb_table[btb_depth];
    logic      [btb_depth -1:0][31:0] pc_table;
    logic      [btb_depth -1:0][31:0] pred_address;
    logic      [btb_depth -1:0][3:0] trimod_counter;
    logic      prediction_table[btb_depth];
    
    //Logic for reading predicted addresss if branch
    
    always_comb begin
            if((pc_at_fetch == pc_table[pc_at_fetch[btb_depth_bits+1:2]]) && prediction_table[pc_at_fetch[btb_depth_bits+1:2]]) begin
                    pcout_at_fetch = pred_address[pc_at_fetch[btb_depth_bits+1:2]];
                    branch_pred_fetch = 1'b1;
            end
            else begin
                    pcout_at_fetch = pc_at_fetch + 'd4;
                    branch_pred_fetch = 1'b0;
            end               
    end
    
  //  always_comb begin
    //        branch_pred = 1'b0;
      //      if((pc_at_decode== btb_table[pc_at_decode[btb_depth_bits+1:2]].pc)) begin
        //            branch_pred = prediction_table[pc_at_decode[btb_depth_bits+1:2]];
          //  end
                 
    //end
    
    
    
    //logic to obtain prediction - done combinationally
    always_comb begin
    for (int i=0; i < btb_depth; i++) begin
       
       prediction_table[i] = ((trimod_counter[i] == WT0) || (trimod_counter[i] == WT1) || (trimod_counter[i] == WT2) || (trimod_counter[i] == WT3)) ? 1'b1:1'b0;
    end
    end
    
   //Logic to update btb table entry at fetch and updating the prediction using pc data at commit
   
   always_ff @(posedge clk) begin
        if(rst) begin
            for(int i=0; i<btb_depth; i++) begin
                pc_table[i] <= '0;
                pred_address[i] <= 'x;
             
                trimod_counter[i] <= NT0;           
            end
        end
        
        else begin
        
        //Updating BTB and counters for jal inst
        
         if((pc_at_commit.pc != pc_table[pc_at_commit.pc[btb_depth_bits+1:2]]) && (pc_at_commit.jal_inst) && pc_at_commit.ready && pc_at_commit.valid) begin
                pc_table[pc_at_commit.pc[btb_depth_bits+1:2]] <= pc_at_commit.pc;
                pred_address[pc_at_commit.pc[btb_depth_bits+1:2]] <= pc_at_commit.pred_branch_address; 

                trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] <= WT0;
            end
            
            else if((pc_at_commit.jal_inst && pc_at_commit.ready && pc_at_commit.valid) && (pc_at_commit.pc == pc_table[pc_at_commit.pc[btb_depth_bits+1:2]])) begin
                    
                        // btb_table[pc_at_commit.pc[btb_depth_bits+1:2]].pred_address <= pc_at_commit.pred_branch_address;
                       
                         trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] <= (trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] == WT3)? WT3 : trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] +1'b1; 

            end
        
        
        
        //Updating BTB and counters for branch instruction
            if((pc_at_commit.pc != pc_table[pc_at_commit.pc[btb_depth_bits+1:2]]) && (pc_at_commit.branch_inst) && pc_at_commit.ready && pc_at_commit.valid) begin
                pc_table[pc_at_commit.pc[btb_depth_bits+1:2]] <= pc_at_commit.pc;
                pred_address[pc_at_commit.pc[btb_depth_bits+1:2]] <= pc_at_commit.pred_branch_address;  
                trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] <= pc_at_commit.branch_resol ? WT0:NT0;
            end
            
            else if((pc_at_commit.branch_inst && pc_at_commit.ready && pc_at_commit.valid) && (pc_at_commit.pc == pc_table[pc_at_commit.pc[btb_depth_bits+1:2]])) begin
                    
                    if(pc_at_commit.branch_resol) begin
                        // btb_table[pc_at_commit.pc[btb_depth_bits+1:2]].pred_address <= pc_at_commit.pred_branch_address;
                      
                         trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] <= (trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] == WT3)? WT3 : trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] +1'b1; 
                            
                    end
                    else begin
                       
trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] <= (trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] == NT3)? NT3 : trimod_counter[pc_at_commit.pc[btb_depth_bits+1:2]] - 1'b1; 
                    end
            end
        end
        
   end


endmodule : btb
