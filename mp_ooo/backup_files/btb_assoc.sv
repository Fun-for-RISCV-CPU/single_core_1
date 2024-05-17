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

logic [4:0] fetch_idx, commit_idx;

assign fetch_idx =  pc_at_fetch[btb_depth_bits+2:3];
assign commit_idx =  pc_at_commit.pc[btb_depth_bits+2:3];


    //btb_entry btb_table[btb_depth];
    logic      [btb_depth -1:0][63:0] pc_table;
    logic      [btb_depth -1:0][63:0] pred_address;
    logic      [btb_depth -1:0][7:0] trimod_counter;
    logic      [btb_depth -1:0][1:0] prediction_table;
    logic      [btb_depth -1:0][1:0] valid_table;
    logic ru_bit[btb_depth];
    logic second_idx;
    //Logic for reading predicted addresss if branch
    assign second_idx = index_finder(valid_table[commit_idx], ru_bit[commit_idx]);
    always_comb begin
            if((pc_at_fetch == pc_table[fetch_idx][31:0]) && prediction_table[fetch_idx][0]) begin
                    pcout_at_fetch = pred_address[fetch_idx][31:0];
                    branch_pred_fetch = 1'b1;
            end
            
            else if((pc_at_fetch == pc_table[fetch_idx][63:32]) && prediction_table[fetch_idx][1]) begin
                  pcout_at_fetch = pred_address[fetch_idx][63:32];
                  branch_pred_fetch = 1'b1;
            end
            else begin
                    pcout_at_fetch = pc_at_fetch + 'd4;
                    branch_pred_fetch = 1'b0;
            end               
    end
    
  //  always_comb begin
    //        branch_pred = 1'b0;
      //      if((pc_at_decode== btb_table[pc_at_decode[btb_depth_bits-1:0]].pc)) begin
        //            branch_pred = prediction_table[pc_at_decode[btb_depth_bits-1:0]];
          //  end
                 
    //end
    
    
    
    //logic to obtain prediction - done combinationally
    always_comb begin
    for (int i=0; i < btb_depth; i++) begin
       
       prediction_table[i][0] = ((trimod_counter[i][3:0] == WT0) || (trimod_counter[i][3:0] == WT1) || (trimod_counter[i][3:0] == WT2) || (trimod_counter[i][3:0] == WT3)) ? 1'b1:1'b0;
       prediction_table[i][1] = ((trimod_counter[i][7:4] == WT0) || (trimod_counter[i][7:4] == WT1) || (trimod_counter[i][7:4] == WT2) || (trimod_counter[i][7:4] == WT3)) ? 1'b1:1'b0;
    end
    end
    
   //Logic to update btb table entry at fetch and updating the prediction using pc data at commit
   
   always_ff @(posedge clk) begin
        if(rst) begin
            for(int i=0; i<btb_depth; i++) begin
                pc_table[i] <= '0;
                pred_address[i] <= 'x;
                valid_table[i] <= '0;
             
                trimod_counter[i][7:4] <= NT0;   
                trimod_counter[i][3:0] <= NT0;         
            end
        end
        
        else begin
        
        //Updating BTB and counters for jal inst
        
         if((pc_at_commit.pc != pc_table[commit_idx][31:0]) && (pc_at_commit.pc != pc_table[commit_idx][63:32]) && (pc_at_commit.jal_inst || pc_at_commit.branch_inst) && pc_at_commit.ready && pc_at_commit.valid) begin
                    if(second_idx) begin
                   pc_table[commit_idx][63:32] <= pc_at_commit.pc;
                    pred_address[commit_idx][63:32] <= pc_at_commit.pred_branch_address; 
                    if(pc_at_commit.jal_inst) trimod_counter[commit_idx][7:4] <= WT0;
                    else if(pc_at_commit.branch_inst && pc_at_commit.branch_resol) trimod_counter[commit_idx][7:4] <= WT0;
                    else trimod_counter[commit_idx][7:4] <= NT0;
                    valid_table[commit_idx][1] <= 1'b1;
                    ru_bit[commit_idx] <= 1'b1;
                end
                else begin
                    pc_table[commit_idx][31:0] <= pc_at_commit.pc;
                    pred_address[commit_idx][31:0] <= pc_at_commit.pred_branch_address; 
                    if(pc_at_commit.jal_inst) trimod_counter[commit_idx][3:0] <= WT0;
                    else if(pc_at_commit.branch_inst && pc_at_commit.branch_resol) trimod_counter[commit_idx][3:0] <= WT0;
                    else trimod_counter[commit_idx][3:0] <= NT0;
                    valid_table[commit_idx][0] <= 1'b1;
                    ru_bit[commit_idx] <= 1'b0;
                end
            end
            
            
            else if((pc_at_commit.jal_inst && pc_at_commit.ready && pc_at_commit.valid) && ((pc_at_commit.pc == pc_table[commit_idx][63:32])|| (pc_at_commit.pc == pc_table[commit_idx][31:0]))) begin
                    
                        // btb_table[pc_at_cmmit.pc[btb_depth_bits-1:0]].pred_address <= pc_at_commit.pred_branch_address;
                         if(pc_at_commit.pc == pc_table[commit_idx][31:0])
                         trimod_counter[commit_idx][3:0] <= (trimod_counter[commit_idx][3:0] == WT3)? WT3 : trimod_counter[commit_idx][3:0] +1'b1; 
                         else trimod_counter[commit_idx][7:4] <= (trimod_counter[commit_idx][7:4] == WT3)? WT3 : trimod_counter[commit_idx][7:4] +1'b1;                           
            end
        
        
        
        //Updating BTB and counters for branch instruction
            else if((pc_at_commit.branch_inst && pc_at_commit.ready && pc_at_commit.valid) && (pc_at_commit.pc == pc_table[commit_idx][63:32]) || (pc_at_commit.pc == pc_table[commit_idx][31:0])) begin
                    
                    if(pc_at_commit.branch_resol) begin
                        // btb_table[pc_at_commit.pc[btb_depth_bits-1:0]].pred_address <= pc_at_commit.pred_branch_address;
                        if(pc_at_commit.pc == pc_table[commit_idx][31:0])
                         trimod_counter[commit_idx][3:0] <= (trimod_counter[commit_idx][3:0] == WT3)? WT3 : trimod_counter[commit_idx][3:0] +1'b1;
                         else
                         trimod_counter[commit_idx][7:4] <= (trimod_counter[commit_idx][7:4] == WT3)? WT3 : trimod_counter[commit_idx][7:4] +1'b1; 
                            
                    end
                    else begin
                       
                    if(pc_at_commit.pc == pc_table[commit_idx][31:0])
                         trimod_counter[commit_idx][3:0] <= (trimod_counter[commit_idx][3:0] == NT3)? NT3 : trimod_counter[commit_idx][3:0] -1'b1;
                         else
                         trimod_counter[commit_idx][7:4] <= (trimod_counter[commit_idx][7:4] == NT3)? NT3 : trimod_counter[commit_idx][7:4] -1'b1; 
                    end
            end
        end
        
   end
function logic index_finder(logic [1:0] valid_bits, logic ru_bit);
if(!valid_bits[0]) return 1'b0;
else if(!valid_bits[1]) return 1'b1;
else
if (ru_bit) return 1'b0;
else return 1'b1;
endfunction

endmodule : btb
