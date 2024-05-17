module btb
import rv32i_types::*;
#(parameter btb_depth = 1024, btb_depth_bits = 10, gshare_depth_bits = GSHARE_DEPTH_BITS, gshare_depth = 1024)
(
    input   logic   clk,
    input   logic   rst,
    input    logic  [31:0] pc_at_fetch,
    output    logic [31:0] pcout_at_fetch,
    input  rob_to_btb_bus pc_at_commit,
    output  logic  branch_pred_fetch,
    input  logic  predictor_choice,
    output logic      [gshare_depth_bits - 1: 0] GHR
);

    //btb_entry btb_table[btb_depth];
    logic      [btb_depth -1:0][31:0] pc_table;
    logic      [btb_depth -1:0][31:0] pred_address;
    logic      [btb_depth -1:0][1:0] bimod_counter;
     logic      [gshare_depth -1:0][1:0] bimod_counter_gshare;
    logic      [btb_depth -1:0][3:0] trimod_counter;
    logic      prediction_table[btb_depth];
    logic      prediction_table_gshare[gshare_depth];
    
    logic [gshare_depth_bits - 1:0]      gshare_index;
    logic check_prediction;
    
    
    //Indexing Logic for gshare
    
    assign gshare_index = GHR ^ pc_at_fetch[gshare_depth_bits + 10:10];
    
    
    //Logic for reading predicted addresss if branch if bimodal counter used
    always_comb begin
    check_prediction = 1'b0;
            case (predictor_choice)
            1'b0: begin
              if((pc_at_fetch == pc_table[pc_at_fetch[btb_depth_bits-1:0]]) && prediction_table[pc_at_fetch[btb_depth_bits-1:0]]) begin
                      pcout_at_fetch = pred_address[pc_at_fetch[btb_depth_bits-1:0]];
                      branch_pred_fetch = 1'b1;
              end
              else begin
                      pcout_at_fetch = pc_at_fetch + 'd4;
                      branch_pred_fetch = 1'b0;
              end
            end
            
            1'b1: begin
              if((pc_at_fetch == pc_table[pc_at_fetch[btb_depth_bits-1:0]]) && prediction_table_gshare[gshare_index]) begin
                      pcout_at_fetch = pred_address[pc_at_fetch[btb_depth_bits-1:0]];
                      branch_pred_fetch = 1'b1;
              end
              else begin
                      pcout_at_fetch = pc_at_fetch + 'd4;
                      branch_pred_fetch = 1'b0;
              end
              if(prediction_table_gshare[gshare_index]) begin
                  check_prediction = 1'b1;
              end
            end
            endcase               
    end
    
    
    
    //logic to obtain prediction - done combinationally
    always_comb begin
      for (int i = 0; i < btb_depth; i++) begin
        prediction_table[i] = 1'b0;
    end
    
    for (int i = 0; i < gshare_depth; i++) begin
        prediction_table_gshare[i] = ((bimod_counter_gshare[i] == wt) || (bimod_counter_gshare[i] == st)) ? 1'b1:1'b0;
    end
    end
    
    
    
   //Logic to update btb table entry at fetch and updating the prediction using pc data at commit
   
   always_ff @(posedge clk) begin
        if(rst) begin
            for(int i=0; i<btb_depth; i++) begin
                pc_table[i] <= '0;
                pred_address[i] <= 'x;
                bimod_counter[i] <= wnt;  
                trimod_counter[i] <= NT0;
                GHR <= '0;          
            end
            
            for(int i=0; i<gshare_depth; i++) begin
                bimod_counter_gshare[i] <= wnt;
            end
        end
        
        else begin
        
        //Updating BTB and counters for jal inst
        
         if((pc_at_commit.pc != pc_table[pc_at_commit.gshare_index]) && (pc_at_commit.jal_inst) && pc_at_commit.ready && pc_at_commit.valid) begin
                pc_table[pc_at_commit.gshare_index] <= pc_at_commit.pc;
                pred_address[pc_at_commit.gshare_index] <= pc_at_commit.pred_branch_address; 
                bimod_counter[pc_at_commit.gshare_index] <= wt;  
                trimod_counter[pc_at_commit.gshare_index] <= WT0;
                GHR <= {GHR[gshare_depth_bits - 2:0],pc_at_commit.branch_update};
                bimod_counter_gshare[pc_at_commit.gshare_index] <= wt;
            end
            
            else if((pc_at_commit.jal_inst && pc_at_commit.ready && pc_at_commit.valid) && (pc_at_commit.pc == pc_table[pc_at_commit.gshare_index])) begin
                    
                       bimod_counter[pc_at_commit.gshare_index] <= (bimod_counter[pc_at_commit.gshare_index]
== st)? st : bimod_counter[pc_at_commit.gshare_index] +1'b1; 
                         trimod_counter[pc_at_commit.gshare_index] <= (trimod_counter[pc_at_commit.gshare_index]
== WT3)? WT3 : trimod_counter[pc_at_commit.gshare_index] +1'b1; 
                        GHR <= {GHR[gshare_depth_bits - 2:0],pc_at_commit.branch_update};
                         bimod_counter_gshare[pc_at_commit.gshare_index] <= (bimod_counter_gshare[pc_at_commit.gshare_index]
== st)? st : bimod_counter_gshare[pc_at_commit.gshare_index] +1'b1;

            end
        
        
        
        //Updating BTB and counters for branch instruction
            if((pc_at_commit.pc != pc_table[pc_at_commit.gshare_index]) && (pc_at_commit.branch_inst) && pc_at_commit.ready && pc_at_commit.valid) begin
                pc_table[pc_at_commit.gshare_index] <= pc_at_commit.pc;
                pred_address[pc_at_commit.gshare_index] <= pc_at_commit.pred_branch_address; 
                bimod_counter[pc_at_commit.gshare_index] <= pc_at_commit.branch_resol ? wt:wnt;  
                trimod_counter[pc_at_commit.gshare_index] <= pc_at_commit.branch_resol ? WT0:NT0;
                GHR <= {GHR[gshare_depth_bits - 2:0],pc_at_commit.branch_update};
                bimod_counter_gshare[pc_at_commit.gshare_index] <= pc_at_commit.branch_resol ? wt:wnt;  
             
            end
            
            else if((pc_at_commit.branch_inst && pc_at_commit.ready && pc_at_commit.valid) && (pc_at_commit.pc == pc_table[pc_at_commit.gshare_index])) begin
                    GHR <= {GHR[gshare_depth_bits - 2:0],pc_at_commit.branch_update};
                    if(pc_at_commit.branch_resol) begin
                       bimod_counter[pc_at_commit.gshare_index] <= (bimod_counter[pc_at_commit.gshare_index]
== st)? st : bimod_counter[pc_at_commit.gshare_index] +1'b1; 
                         trimod_counter[pc_at_commit.gshare_index] <= (trimod_counter[pc_at_commit.gshare_index]
== WT3)? WT3 : trimod_counter[pc_at_commit.gshare_index] +1'b1; 
   bimod_counter_gshare[pc_at_commit.gshare_index] <= (bimod_counter_gshare[pc_at_commit.gshare_index]
== st)? st : bimod_counter_gshare[pc_at_commit.gshare_index] +1'b1;
                            
                    end
                    else begin
                    GHR <= {GHR[gshare_depth_bits - 2:0],pc_at_commit.branch_update};
                       bimod_counter[pc_at_commit.gshare_index] <= (bimod_counter[pc_at_commit.gshare_index]
== snt)? snt : bimod_counter[pc_at_commit.gshare_index] - 1'b1; 
trimod_counter[pc_at_commit.gshare_index] <= (trimod_counter[pc_at_commit.gshare_index]
== NT3)? NT3 : trimod_counter[pc_at_commit.gshare_index] - 1'b1;
   bimod_counter_gshare[pc_at_commit.gshare_index] <= (bimod_counter_gshare[pc_at_commit.gshare_index]
== snt)? snt : bimod_counter_gshare[pc_at_commit.gshare_index] - 1'b1;
                    end
            end
        end
        
   end


endmodule : btb
