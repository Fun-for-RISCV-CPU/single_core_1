module rob
import rv32i_types::*;
#(parameter depth_bits = ROB_ID_SIZE, parameter decode_ports = SS_DISPATCH_WIDTH, parameter load_ports = 1, parameter store_ports = 1, parameter mem_ports = 1, parameter ex_ports = EX_UNITS, parameter data_wb_ports = COMMIT_FACTOR)
(
    // Global inputs
    input logic                                         clk,
    input logic                                         rst,
    
    // Input ports
    input ex_data_bus_t                                 ex_data_bus[ex_ports], // One data bus for for each execution unit
    input decode_rob_bus_t      [decode_ports-1:0]      decode_rob_bus, // Data bus directly from decode to ROB
    input mem_rob_data_bus_t    [mem_ports-1:0]         mem_rob_data_bus,
    input ls_rob_data_bus_t     [load_ports-1:0]        load_rob_data_bus,
    input ls_rob_data_bus_t     [store_ports-1:0]       store_rob_data_bus,
    
    input logic                                         load_mispredict,

    // Forwarded RS1 and RS2 values for RVFI
    input logic                 [ex_ports - 1:0][31:0]  rvfi_rs1_v, rvfi_rs2_v,             

    // Branching logic
    output logic                                        branch_miss,
    output logic                [31:0]                  br_address,

    // Broadcast data
    output rob_entry_t          [2**depth_bits-1:0]     rob_arr, // ROB array. Note that RVFI data is not included here
    output logic                [depth_bits-1:0]        head_ptr,
    output logic                                        rob_full,

    // Output ports
    output rob_reg_data_bus_t   [data_wb_ports-1:0]     rob_reg_data_bus,
    output rvfi_data_t          [data_wb_ports-1:0]     rvfi_output,
    output  logic [depth_bits-1:0]    tail_ptr,
	output	rob_to_btb_bus  pc_at_commit
);

    localparam                          DEPTH = 2**depth_bits;
    localparam  bit [depth_bits-1:0]    FULL = '1;
    localparam                          MAX_COMMIT = 4;

    rvfi_data_t [DEPTH-1:0]            rvfi_data_arr; // RVFI data that will be in parallel to ROB entry

    // Internal ROB logic variables
    logic [depth_bits-1:0]    head_ptr_next;
    logic [63:0]              order;
    logic [63:0]              order_next;
    logic [depth_bits-1:0]    rob_count, rob_count_next;
    logic [data_wb_ports-1:0] multi_commit; // Thermometer encoded number of inst to commit
    logic [3:0]               commit_no;
    logic [3:0]               dispatch_no;   

assign order_next = order + commit_no;
assign rob_count_next = rob_count + dispatch_no - commit_no;
// Superscalar head_ptr update
assign head_ptr_next = head_ptr + dispatch_no;
    //Logic for gshare branch_predictor
    
    //logic for pipelining stuff from ex data bus
    
   // ex_data_bus_t                                 ex_data_bus[ex_ports];
    
   // always_ff @(posedge clk) begin
  //  for(int i = 0; i < ex_ports; i++) begin
   //     ex_data_bus[i] <= ex_data_bus_int[i];
  //  end
  //  end
    
    
	
// Updating ROB to BTB bus	
always_comb begin
    pc_at_commit.branch_resol = rob_arr[tail_ptr + commit_no - 4'(1)].rd_data[0];
    pc_at_commit.branch_inst = rob_arr[tail_ptr + commit_no - 4'(1)].branch_inst;
    pc_at_commit.pred_branch_address = rob_arr[tail_ptr + commit_no - 4'(1)].branch_address;
    pc_at_commit.pc = rob_arr[tail_ptr + commit_no - 4'(1)].pc;
    pc_at_commit.ready = rob_arr[tail_ptr + commit_no - 4'(1)].ready;
    pc_at_commit.valid = rob_arr[tail_ptr + commit_no - 4'(1)].valid;
    pc_at_commit.jal_inst = rob_arr[tail_ptr + commit_no - 4'(1)].jal_inst;

    // ROB full logic
    if (rob_count >= (FULL - 3'b100)) begin
        rob_full = 1'b1;
    end else begin
        rob_full = 1'b0;
    end
     
    // Next order including multi commit
    dispatch_no = '0;
    for (int i=0; i< SS_DISPATCH_WIDTH; i++)begin
        if (decode_rob_bus[i].ready)
            dispatch_no = dispatch_no + 1'b1;
    end

    if (rob_arr[tail_ptr].ready && rob_arr[tail_ptr].valid || (mem_rob_data_bus[0].ready && rob_arr[mem_rob_data_bus[0].rob_id].valid && mem_rob_data_bus[0].store)) begin
        // Thermometer encoded number of entries ready for parallel commit
        //multi_commit[0] = rob_arr[tail_ptr].ready && rob_arr[tail_ptr].valid;
        multi_commit[0] = 1'b1;
        commit_no = 4'b0001;
        // if (multi_commit[0]) begin
        //     commit_no = commit_no + 1'b1;
        // end
        for (int i = 1; i < data_wb_ports; i++) begin
            if(rob_arr[tail_ptr + depth_bits'(i)].valid && rob_arr[tail_ptr + depth_bits'(i)].ready && i < MAX_COMMIT) begin
                multi_commit[i] = multi_commit[i-4'(1)] && // Previous instruction is ready
                                ! ((rob_arr[tail_ptr + depth_bits'(i) - 4'(1)].branch_inst) || // Previous inst not Mispredicted branch
                                rob_arr[tail_ptr + depth_bits'(i) - 4'(1)].jump_inst ||  // previous inst not Jump
                                rob_arr[tail_ptr + depth_bits'(i) - 4'(1)].store_inst); 
                if(multi_commit[i]) begin
                    commit_no = commit_no + 1'b1;
                end
            end else begin
                multi_commit[i] = 1'b0;
            end
        end
    end else begin
        for (int i = 0; i < data_wb_ports; i++) begin
            multi_commit[i] = 1'b0;
        end
        commit_no = 4'b0000;
    end

end

always_ff @(posedge clk) begin
    
    // Reset logic and head ptr update
    // Reset ROB on branch miss (after instruction commit)
    if (rst) begin
        head_ptr <= '0;
        tail_ptr <= '0;
        order    <= '0;
        rvfi_output <= '0;
        branch_miss <= 1'b0;
        br_address  <= 'x;
        rob_count <= '0;

        // Invaldiate all ROB entries so any instrcutions sitting in reservation stations are not commited
        for (int i = 0; i < DEPTH; i++) begin
            rob_arr[i].valid <= 1'b0;
        end
    end 
    else if (branch_miss) begin
        head_ptr <= '0;
        tail_ptr <= '0;
        rvfi_output <= '0;
        branch_miss <= 1'b0;
        br_address  <= 'x;
        rob_count <= '0;

        // Invaldiate all ROB entries so any instrcutions sitting in reservation stations are not commited
        for (int i = 0; i < DEPTH; i++) begin
            rob_arr[i].valid <= 1'b0;
        end
    end
    else begin
        rob_count <= rob_count_next;
        branch_miss <= 1'b0;
        br_address  <= 'x;
        ///////////////
        // MULTI-COMMIT LOGIC
        ///////////////
        // Check if item at tail has op_complete == 1 -> Send out data to reg file and update tail
        if (rob_arr[tail_ptr].ready && rob_arr[tail_ptr].valid || (mem_rob_data_bus[0].ready && rob_arr[mem_rob_data_bus[0].rob_id].valid && mem_rob_data_bus[0].store && mem_rob_data_bus[0].rob_id == (tail_ptr + commit_no - 4'(1)))) begin
            unique case(multi_commit)
                4'b0001: begin
                    for (int i = 0; i < 1; i++) begin
                        // Put data on bus
                        rob_reg_data_bus[i].ready <= 1'b1;
                        rob_reg_data_bus[i].rd_data <= rob_arr[tail_ptr + depth_bits'(i)].rd_data;
                        rob_reg_data_bus[i].rd_addr <= rob_arr[tail_ptr + depth_bits'(i)].rd_addr;
                        rob_reg_data_bus[i].rob_id <= tail_ptr + depth_bits'(i);
                        // Invalidate tail
                        rob_arr[tail_ptr + depth_bits'(i)].valid <= 1'b0;
                        //rob_arr[tail_ptr + depth_bits'(i)].ready <= 1'b0;
        
                        // Output RVFI
                        rvfi_output[i].monitor_valid <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_valid;
                        //rvfi_output[i].monitor_order <= order; //i; // Update order
                        rvfi_output[i].monitor_order <= order + depth_bits'(i); // Update order
                        rvfi_output[i].monitor_inst <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_inst;
                        rvfi_output[i].monitor_rs1_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs1_addr;
                        rvfi_output[i].monitor_rs2_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs2_addr;
                        rvfi_output[i].monitor_rs1_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs1_rdata;
                        rvfi_output[i].monitor_rs2_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs2_rdata;
                        rvfi_output[i].monitor_regf_we <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_regf_we;
                        rvfi_output[i].monitor_rd_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rd_addr;
                        rvfi_output[i].monitor_rd_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rd_wdata;
                        rvfi_output[i].monitor_pc_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_pc_rdata;
                        rvfi_output[i].monitor_pc_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_pc_wdata;
                        rvfi_output[i].monitor_mem_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_addr;
                        rvfi_output[i].monitor_mem_rmask <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_rmask;
                        rvfi_output[i].monitor_mem_wmask <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_wmask;
                        rvfi_output[i].monitor_mem_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_rdata;
                        rvfi_output[i].monitor_mem_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_wdata;
                    end

                    // Ensure other RVFI are invlaid
                    for (int i = 1; i < 4; i++) begin
                        rob_reg_data_bus[i].ready <= 1'b0;
                        rvfi_output[i].monitor_valid <= '0;
                    end
                end
                4'b0011: begin
                    for (int i = 0; i < 2; i++) begin
                        // Put data on bus
                        rob_reg_data_bus[i].ready <= 1'b1;
                        rob_reg_data_bus[i].rd_data <= rob_arr[tail_ptr + depth_bits'(i)].rd_data;
                        rob_reg_data_bus[i].rd_addr <= rob_arr[tail_ptr + depth_bits'(i)].rd_addr;
                        rob_reg_data_bus[i].rob_id <= tail_ptr + depth_bits'(i);
                        // Invalidate tail
                        rob_arr[tail_ptr + depth_bits'(i)].valid <= 1'b0;
                        //rob_arr[tail_ptr + depth_bits'(i)].ready <= 1'b0;
        
                        // Output RVFI
                        rvfi_output[i].monitor_valid <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_valid;
                        //rvfi_output[i].monitor_order <= order; // + depth_bits'(i); // Update order
                        rvfi_output[i].monitor_order <= order + depth_bits'(i); // Update order
                        rvfi_output[i].monitor_inst <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_inst;
                        rvfi_output[i].monitor_rs1_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs1_addr;
                        rvfi_output[i].monitor_rs2_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs2_addr;
                        rvfi_output[i].monitor_rs1_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs1_rdata;
                        rvfi_output[i].monitor_rs2_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs2_rdata;
                        rvfi_output[i].monitor_regf_we <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_regf_we;
                        rvfi_output[i].monitor_rd_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rd_addr;
                        rvfi_output[i].monitor_rd_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rd_wdata;
                        rvfi_output[i].monitor_pc_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_pc_rdata;
                        rvfi_output[i].monitor_pc_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_pc_wdata;
                        rvfi_output[i].monitor_mem_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_addr;
                        rvfi_output[i].monitor_mem_rmask <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_rmask;
                        rvfi_output[i].monitor_mem_wmask <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_wmask;
                        rvfi_output[i].monitor_mem_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_rdata;
                        rvfi_output[i].monitor_mem_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_wdata;
                    end

                    // Ensure other RVFI are invlaid
                    for (int i = 2; i < 4; i++) begin
                        rob_reg_data_bus[i].ready <= 1'b0;
                        rvfi_output[i].monitor_valid <= '0;
                    end
                end
                4'b0111: begin
                    for (int i = 0; i < 3; i++) begin
                        // Put data on bus
                        rob_reg_data_bus[i].ready <= 1'b1;
                        rob_reg_data_bus[i].rd_data <= rob_arr[tail_ptr + depth_bits'(i)].rd_data;
                        rob_reg_data_bus[i].rd_addr <= rob_arr[tail_ptr + depth_bits'(i)].rd_addr;
                        rob_reg_data_bus[i].rob_id <= tail_ptr + depth_bits'(i);
                        // Invalidate tail
                        rob_arr[tail_ptr + depth_bits'(i)].valid <= 1'b0;
                        //rob_arr[tail_ptr + depth_bits'(i)].ready <= 1'b0;
        
                        // Output RVFI
                        rvfi_output[i].monitor_valid <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_valid;
                        //rvfi_output[i].monitor_order <= order; // + depth_bits'(i); // Update order
                        rvfi_output[i].monitor_order <= order + depth_bits'(i); // Update order
                        rvfi_output[i].monitor_inst <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_inst;
                        rvfi_output[i].monitor_rs1_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs1_addr;
                        rvfi_output[i].monitor_rs2_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs2_addr;
                        rvfi_output[i].monitor_rs1_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs1_rdata;
                        rvfi_output[i].monitor_rs2_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs2_rdata;
                        rvfi_output[i].monitor_regf_we <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_regf_we;
                        rvfi_output[i].monitor_rd_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rd_addr;
                        rvfi_output[i].monitor_rd_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rd_wdata;
                        rvfi_output[i].monitor_pc_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_pc_rdata;
                        rvfi_output[i].monitor_pc_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_pc_wdata;
                        rvfi_output[i].monitor_mem_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_addr;
                        rvfi_output[i].monitor_mem_rmask <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_rmask;
                        rvfi_output[i].monitor_mem_wmask <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_wmask;
                        rvfi_output[i].monitor_mem_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_rdata;
                        rvfi_output[i].monitor_mem_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_wdata;

                        // Ensure other RVFI are invlaid
                        for (int i = 3; i < 4; i++) begin
                            rob_reg_data_bus[i].ready <= 1'b0;
                            rvfi_output[i].monitor_valid <= '0;
                        end
                    end
                end
                4'b1111: begin
                    for (int i = 0; i < 4; i++) begin
                        // Put data on bus
                        rob_reg_data_bus[i].ready <= 1'b1;
                        rob_reg_data_bus[i].rd_data <= rob_arr[tail_ptr + depth_bits'(i)].rd_data;
                        rob_reg_data_bus[i].rd_addr <= rob_arr[tail_ptr + depth_bits'(i)].rd_addr;
                        rob_reg_data_bus[i].rob_id <= tail_ptr + depth_bits'(i);
                        // Invalidate tail
                        rob_arr[tail_ptr + depth_bits'(i)].valid <= 1'b0;
                        //rob_arr[tail_ptr + depth_bits'(i)].ready <= 1'b0;
        
                        // Output RVFI
                        rvfi_output[i].monitor_valid <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_valid;
                        //rvfi_output[i].monitor_order <= order + depth_bits'(i); // Update order
                        rvfi_output[i].monitor_order <= order + depth_bits'(i); // Update order
                        rvfi_output[i].monitor_inst <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_inst;
                        rvfi_output[i].monitor_rs1_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs1_addr;
                        rvfi_output[i].monitor_rs2_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs2_addr;
                        rvfi_output[i].monitor_rs1_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs1_rdata;
                        rvfi_output[i].monitor_rs2_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rs2_rdata;
                        rvfi_output[i].monitor_regf_we <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_regf_we;
                        rvfi_output[i].monitor_rd_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rd_addr;
                        rvfi_output[i].monitor_rd_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_rd_wdata;
                        rvfi_output[i].monitor_pc_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_pc_rdata;
                        rvfi_output[i].monitor_pc_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_pc_wdata;
                        rvfi_output[i].monitor_mem_addr <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_addr;
                        rvfi_output[i].monitor_mem_rmask <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_rmask;
                        rvfi_output[i].monitor_mem_wmask <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_wmask;
                        rvfi_output[i].monitor_mem_rdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_rdata;
                        rvfi_output[i].monitor_mem_wdata <= rvfi_data_arr[tail_ptr + depth_bits'(i)].monitor_mem_wdata;
        
                    end
                end
                default: begin
                end
            endcase

            // Branch instruction flush if prediction is incorrect
            // If there is a branch/jump being committed, it is guaranteed to be the last index 
            // in multi-commit due to multi-commit counting logic
            // Case 1: Branch Misprediction
            // Case 2: Jump Instruction
			//Prediction was correct
            if ((rob_arr[tail_ptr + commit_no - 4'(1)].branch_inst &&
                (rob_arr[tail_ptr + commit_no - 4'(1)].branch_pred == rob_arr[tail_ptr + commit_no - 4'(1)].rd_data[0]))) begin
                branch_miss <= 1'b0;
                br_address  <= rob_arr[tail_ptr + commit_no - 4'(1)].rd_data[0] ? (rob_arr[tail_ptr + commit_no - 4'(1)].branch_address) : (rob_arr[tail_ptr + commit_no - 4'(1)].pc + 'd4);
            end
			else if ((rob_arr[tail_ptr + commit_no - 4'(1)].branch_inst &&
                (rob_arr[tail_ptr + commit_no - 4'(1)].branch_pred != rob_arr[tail_ptr + commit_no - 4'(1)].rd_data[0]))) begin
				branch_miss <= 1'b1;
				br_address <= rob_arr[tail_ptr + commit_no - 4'(1)].rd_data[0]? rob_arr[tail_ptr + commit_no - 4'(1)].branch_address : (rob_arr[tail_ptr + commit_no - 4'(1)].pc + 4);
				end
        
            else if(rob_arr[tail_ptr + commit_no - 4'(1)].jal_inst && rob_arr[tail_ptr + commit_no - 4'(1)].branch_pred) begin
                branch_miss <= 1'b0;
                br_address  <= rob_arr[tail_ptr + commit_no - 4'(1)].branch_address;	
            end
            
            else if(rob_arr[tail_ptr + commit_no - 4'(1)].jal_inst && !rob_arr[tail_ptr + commit_no - 4'(1)].branch_pred) begin
                branch_miss <= 1'b1;
                br_address  <= rob_arr[tail_ptr + commit_no - 4'(1)].branch_address;	
            end
            
            else if(rob_arr[tail_ptr + commit_no - 4'(1)].jump_inst && !rob_arr[tail_ptr + commit_no - 4'(1)].jal_inst) begin
                    branch_miss <= 1'b1;
                    br_address  <= rob_arr[tail_ptr + commit_no - 4'(1)].branch_address;	
            end
            else if (load_mispredict) begin
                branch_miss <= 1'b1;
                br_address  <= rob_arr[tail_ptr + commit_no - 4'(1)].pc + 'd4;
            end
            else begin
                branch_miss <= 1'b0;
            end

            // Update tail and order
            tail_ptr <= tail_ptr + commit_no;
            order    <= order_next;
            
        end else begin
            for (int i = 0; i < data_wb_ports; i++) begin
                // Set data on bus to invalid and 'x
                rob_reg_data_bus[i].ready <= 1'b0;
                rob_reg_data_bus[i].rd_data <= 'x;
                rob_reg_data_bus[i].rd_addr <= 'x;
                // Invalidate RVFI output if no new commit
                rvfi_output[i].monitor_valid <= 1'b0; 
            end
            // Update tail
            tail_ptr <= tail_ptr;
        end

        //////////////////////////
        // DECODE -> ROB BUS LOGIC
        //////////////////////////

        // Add new items from decode bus(es) into rob entries
        for (int i = 0; i < decode_ports; i++) begin
            if (decode_rob_bus[i].ready == 1'b1) begin
                rob_arr[head_ptr + depth_bits'(i)].ready          <= 1'b0;
                rob_arr[head_ptr + depth_bits'(i)].valid         <= 1'b1;
                rob_arr[head_ptr + depth_bits'(i)].branch_inst   <= decode_rob_bus[i].branch_inst;
                rob_arr[head_ptr + depth_bits'(i)].jump_inst     <= decode_rob_bus[i].jump_inst;
                rob_arr[head_ptr + depth_bits'(i)].jal_inst     <= decode_rob_bus[i].jal_inst;
                rob_arr[head_ptr + depth_bits'(i)].mem_inst      <= decode_rob_bus[i].mem_inst;
                rob_arr[head_ptr + depth_bits'(i)].store_inst      <= decode_rob_bus[i].store_inst;
                rob_arr[head_ptr + depth_bits'(i)].branch_pred  <= decode_rob_bus[i].branch_pred;
                rob_arr[head_ptr + depth_bits'(i)].branch_address <= decode_rob_bus[i].branch_address;
                rob_arr[head_ptr + depth_bits'(i)].pc            <= decode_rob_bus[i].pc;
                rob_arr[head_ptr + depth_bits'(i)].rd_addr       <= decode_rob_bus[i].rd_addr;
                rob_arr[head_ptr + depth_bits'(i)].rd_data       <= 'x;
                
                // Validate entry
                rob_arr[head_ptr + depth_bits'(i)].valid <= 1'b1;
                
                rvfi_data_arr[head_ptr + depth_bits'(i)] <= decode_rob_bus[i].rvfi_data;

                // Increment head pointer
                head_ptr <= head_ptr_next;
            end
        end

        //////////////////////////
        // EX_UNIT -> ROB BUS LOGIC
        //////////////////////////
            
        // Update items in ROB based on number of valid entries on data bus
        for (int i = 0; i < ex_ports; i++) begin
            // Data on bus is valid, update the data field in the ROB entry and mark op_complete
            if (ex_data_bus[i].ready && rob_arr[ex_data_bus[i].rob_id].valid) begin
                // Loading result of branch instruction

                // JALR
                if (rob_arr[ex_data_bus[i].rob_id].jump_inst) begin
                    rob_arr[ex_data_bus[i].rob_id].branch_address <= ex_data_bus[i].rd_data & 32'hfffffffe;
                    rvfi_data_arr[ex_data_bus[i].rob_id].monitor_pc_wdata <= ex_data_bus[i].rd_data & 32'hfffffffe;
                    
                    // Update rd data to PC + 4
                    rob_arr[ex_data_bus[i].rob_id].rd_data <= rob_arr[ex_data_bus[i].rob_id].pc + 32'h00000004;
                    rvfi_data_arr[ex_data_bus[i].rob_id].monitor_rd_wdata <= rob_arr[ex_data_bus[i].rob_id].pc + 32'h00000004;
                end
                // JAL
                else if (rob_arr[ex_data_bus[i].rob_id].jump_inst) begin
                    rob_arr[ex_data_bus[i].rob_id].branch_address <= ex_data_bus[i].rd_data;
                    rvfi_data_arr[ex_data_bus[i].rob_id].monitor_pc_wdata <= ex_data_bus[i].rd_data;

                    // Update rd data to PC + 4
                    rob_arr[ex_data_bus[i].rob_id].rd_data <= rob_arr[ex_data_bus[i].rob_id].pc + 32'h00000004;
                    rvfi_data_arr[ex_data_bus[i].rob_id].monitor_rd_wdata <= rob_arr[ex_data_bus[i].rob_id].pc + 32'h00000004;
                end
                // Branch
                else if (rob_arr[ex_data_bus[i].rob_id].branch_inst) begin
                    // Load result of compare (branch decision)
                    // Branch adress has already been computed
                    rob_arr[ex_data_bus[i].rob_id].rd_data <= ex_data_bus[i].rd_data;

                    // Update the rvfi pc wdata to be branch address if taken. pc + 4 otherwise
                    if (ex_data_bus[i].rd_data[0]) begin
                        rvfi_data_arr[ex_data_bus[i].rob_id].monitor_pc_wdata <= rob_arr[ex_data_bus[i].rob_id].branch_address;
                    end

                    rvfi_data_arr[ex_data_bus[i].rob_id].monitor_rd_wdata  <= ex_data_bus[i].rd_data;
                end
                // Non branch or jump instruction result load
                else begin
                    rob_arr[ex_data_bus[i].rob_id].rd_data <= ex_data_bus[i].rd_data; // Update rd_data field in the ROB
                    rvfi_data_arr[ex_data_bus[i].rob_id].monitor_rd_wdata  <= ex_data_bus[i].rd_data;
                end
                
                // Mark operation complete for all instructions outside of memory instructions
                // Memory instuctions are marked complete by the mem rob data bus
                if (rob_arr[ex_data_bus[i].rob_id].mem_inst != 1'b1) begin
                    rob_arr[ex_data_bus[i].rob_id].ready  <= 1'b1; // Set op_complete to 1
                end else begin
                    rob_arr[ex_data_bus[i].rob_id].ready  <= 1'b0; // Op complete remains 0
                end

                // Update RVFI based on result of execution
                rvfi_data_arr[ex_data_bus[i].rob_id].monitor_rs1_rdata <= rvfi_rs1_v[i];
                rvfi_data_arr[ex_data_bus[i].rob_id].monitor_rs2_rdata <= rvfi_rs2_v[i];
            end
        end

        //////////////////////////
        // MEM Controller -> ROB BUS LOGIC
        //////////////////////////

        // Update items in ROB based on number of valid entries on mem bus
        for (int i = 0; i < mem_ports; i++) begin
            // Update fields based on result of memory instruction
            if (mem_rob_data_bus[i].ready && rob_arr[mem_rob_data_bus[i].rob_id].valid && !mem_rob_data_bus[i].store) begin
                rob_arr[mem_rob_data_bus[i].rob_id].ready  <= 1'b1; // Op complete remains 0
                
                // Update rd_data for load inst
                rob_arr[mem_rob_data_bus[i].rob_id].rd_data <= mem_rob_data_bus[i].rd_data; // Op complete remains 0

                rvfi_data_arr[mem_rob_data_bus[i].rob_id].monitor_rd_wdata <= mem_rob_data_bus[i].rd_data;
                rvfi_data_arr[mem_rob_data_bus[i].rob_id].monitor_mem_rdata <= mem_rob_data_bus[i].dmem_rdata;
                // rvfi_data_arr[mem_rob_data_bus[i].rob_id].monitor_mem_wdata <= mem_rob_data_bus[i].dmem_wdata;
            end
        end

        //////////////////////////
        // Load Queue -> ROB BUS LOGIC
        //////////////////////////

        // Update items in ROB based on number of valid entries on mem bus
        for (int i = 0; i < load_ports; i++) begin
            // Update fields based on result of memory instruction
            if (load_rob_data_bus[i].valid && rob_arr[load_rob_data_bus[i].rob_id].valid) begin
                rob_arr[load_rob_data_bus[i].rob_id].ready  <= load_rob_data_bus[i].ready; // Op complete remains 0
                
                // Update rd_data for load inst
                rob_arr[load_rob_data_bus[i].rob_id].rd_data <= load_rob_data_bus[i].rd_data; // Op complete remains 0

                rvfi_data_arr[load_rob_data_bus[i].rob_id].monitor_rd_wdata <= load_rob_data_bus[i].rd_data;

                rvfi_data_arr[load_rob_data_bus[i].rob_id].monitor_rs1_rdata <= load_rob_data_bus[i].rs1_v;
                rvfi_data_arr[load_rob_data_bus[i].rob_id].monitor_rs2_rdata <= load_rob_data_bus[i].rs2_v;

                rvfi_data_arr[load_rob_data_bus[i].rob_id].monitor_mem_addr  <= load_rob_data_bus[i].dmem_addr;
                rvfi_data_arr[load_rob_data_bus[i].rob_id].monitor_mem_rmask <= load_rob_data_bus[i].dmem_rmask;
                rvfi_data_arr[load_rob_data_bus[i].rob_id].monitor_mem_wmask <= load_rob_data_bus[i].dmem_wmask;
                rvfi_data_arr[load_rob_data_bus[i].rob_id].monitor_mem_rdata <= load_rob_data_bus[i].dmem_rdata;
                rvfi_data_arr[load_rob_data_bus[i].rob_id].monitor_mem_wdata <= load_rob_data_bus[i].dmem_wdata;
            end
        end

        //////////////////////////
        // Store Queue -> ROB BUS LOGIC
        //////////////////////////

        // Update items in ROB based on number of valid entries on mem bus
        for (int i = 0; i < store_ports; i++) begin
            // Update fields based on result of memory instruction
            if (store_rob_data_bus[i].valid && rob_arr[store_rob_data_bus[i].rob_id].valid) begin
                rob_arr[store_rob_data_bus[i].rob_id].ready  <= store_rob_data_bus[i].ready; // Op complete remains 0
                
                // Update rd_data for load inst
                rob_arr[store_rob_data_bus[i].rob_id].rd_data <= store_rob_data_bus[i].rd_data; // Op complete remains 0

                rvfi_data_arr[store_rob_data_bus[i].rob_id].monitor_rd_wdata <= store_rob_data_bus[i].rd_data;

                rvfi_data_arr[store_rob_data_bus[i].rob_id].monitor_rs1_rdata <= store_rob_data_bus[i].rs1_v;
                rvfi_data_arr[store_rob_data_bus[i].rob_id].monitor_rs2_rdata <= store_rob_data_bus[i].rs2_v;

                rvfi_data_arr[store_rob_data_bus[i].rob_id].monitor_mem_addr  <= store_rob_data_bus[i].dmem_addr;
                rvfi_data_arr[store_rob_data_bus[i].rob_id].monitor_mem_rmask <= store_rob_data_bus[i].dmem_rmask;
                rvfi_data_arr[store_rob_data_bus[i].rob_id].monitor_mem_wmask <= store_rob_data_bus[i].dmem_wmask;
                rvfi_data_arr[store_rob_data_bus[i].rob_id].monitor_mem_rdata <= store_rob_data_bus[i].dmem_rdata;
                rvfi_data_arr[store_rob_data_bus[i].rob_id].monitor_mem_wdata <= store_rob_data_bus[i].dmem_wdata;
            end
        end

    end

end

endmodule: rob