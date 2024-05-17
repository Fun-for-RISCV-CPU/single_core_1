module btb
import rv32i_types::*;
#(parameter theta = 30, ghr_size_bits = 7, btb_depth_bits = 7, weight_len = 7, btb_depth = 128)
(
    input   logic   clk,
    input   logic   rst,
    input    logic  [31:0] pc_at_fetch,
    output    logic [31:0] pcout_at_fetch,
    input  rob_to_btb_bus pc_at_commit,
    output  logic  branch_pred_fetch,
   // input  logic  predictor_choice,
    output logic      [ ghr_size_bits - 1: 0] GHR
);

    //btb_entry btb_table[btb_depth];
      logic      [btb_depth -1:0][31:0] pc_table;
    logic      [btb_depth -1:0][31:0] pred_address;
    
    logic [btb_depth_bits - 1:0] commit_idx, fetch_idx;
    
    logic signed  [weight_len - 1: 0] weights_table[btb_depth - 1:0][ghr_size_bits - 1:0];
    logic signed  [weight_len - 1: 0] bias_table[btb_depth - 1:0];
    
    logic signed [31:0] fetch_sum_y, commit_sum_y;
    logic  prediction_fetch, prediction_commit;
    
    logic signed [weight_len-1:0] 		fetch_bias;
	  logic signed [weight_len-1:0] 		commit_bias;
	  logic signed [weight_len-1:0] 		fetch_weights 	[ghr_size_bits-1:0];
	  logic signed [weight_len-1:0] 		commit_weights [ghr_size_bits-1:0];
     
     
      //Calculating the prediction value
              
        assign prediction_fetch = fetch_sum_y[31] ? 1'b0: 1'b1;
        assign prediction_commit = commit_sum_y[31] ? 1'b0:1'b1;
        
     assign commit_idx = pc_at_commit.pc[btb_depth_bits+1:2];
    assign fetch_idx = pc_at_fetch[btb_depth_bits+1:2];
        
    //Calculating bias and weights for both at fetch and commit
    
    assign fetch_bias = bias_table[fetch_idx];
    assign commit_bias = bias_table[commit_idx];
    assign fetch_weights = weights_table[fetch_idx];
    assign commit_weights = weights_table[commit_idx];
    
    //Branch_prediction logic
 always_comb begin
            if((pc_at_fetch == pc_table[fetch_idx]) && prediction_fetch) begin
                    pcout_at_fetch = pred_address[fetch_idx];
                    branch_pred_fetch = 1'b1;
            end
            else begin
                    pcout_at_fetch = pc_at_fetch + 'd4;
                    branch_pred_fetch = 1'b0;
            end               
    end
              
    
    //Calculating the fetch sum and commit sum
    
    always_comb begin
    fetch_sum_y = '0;
    commit_sum_y = '0;
        fetch_sum_y = fetch_sum_y + fetch_bias;
        commit_sum_y = commit_sum_y + commit_bias;
        for(int i = 0; i < ghr_size_bits; i++) begin
            fetch_sum_y = GHR[i] ? $signed(fetch_sum_y) + (fetch_weights[i]) : $signed(fetch_sum_y) - (fetch_weights[i]);
        end
        
        for(int i = 0; i < ghr_size_bits; i++) begin
            commit_sum_y = GHR[i] ? $signed(commit_sum_y) + (commit_weights[i]) : $signed(commit_sum_y) - (commit_weights[i]);
        end
        
    end
    
    //Updating the weights
    
    always_ff @(posedge clk) begin
        if(rst) begin
        GHR <= '0;
        
        for(int i =0; i < btb_depth; i++) begin
            pc_table[i] <= '0;
             bias_table[i] <= '0;
            pred_address[i] <= '0;
            for(int j =0; j < ghr_size_bits; j++) begin
                weights_table[i][j] <= '0;
               
            end
        end
        
        end
        
        else begin
        
         if((pc_at_commit.pc != pc_table[commit_idx]) && (pc_at_commit.jal_inst) && pc_at_commit.ready && pc_at_commit.valid) begin
                pc_table[commit_idx] <= pc_at_commit.pc;
                pred_address[commit_idx] <= pc_at_commit.pred_branch_address; 
            end
            
          if((pc_at_commit.branch_inst) && pc_at_commit.ready && pc_at_commit.valid) begin
               GHR <= {GHR[ghr_size_bits - 2:0], pc_at_commit.branch_update};
               
               if((~commit_sum_y[15] != pc_at_commit.branch_resol) || ((commit_sum_y) >= 0) && ((commit_sum_y) <= theta) || ((commit_sum_y) < 0) && ((-commit_sum_y) >= (-theta)) ) begin
               
                   bias_table[commit_idx] <= pc_at_commit.branch_resol ?  bias_table[commit_idx] + 1: bias_table[commit_idx] - 1;
                   
                    for(int j =0; j < ghr_size_bits; j++) begin
                weights_table[commit_idx][j] <= (pc_at_commit.branch_resol == GHR[j]) ?  weights_table[commit_idx][j] + 1: weights_table[commit_idx][j] - 1;
            end
            
               end 
               
               if((pc_at_commit.pc != pc_table[commit_idx])) begin
               
                    pc_table[commit_idx] <= pc_at_commit.pc;
                    pred_address[commit_idx] <= pc_at_commit.pred_branch_address; 
               
               end
               
                
            end
            
        
        
        end
    end
    
endmodule : btb

