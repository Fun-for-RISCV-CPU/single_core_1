module rob
import rv32i_types::*;
#(parameter depth_bits = ROB_ID_SIZE, parameter decode_ports = 1, parameter load_ports = 1, parameter store_ports = 1, parameter mem_ports = 1, parameter ex_ports = EX_UNITS, parameter data_wb_ports = 1)
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
    output rvfi_data_t                                  rvfi_output,
    output  logic [depth_bits-1:0]    tail_ptr,
	output	rob_to_btb_bus  pc_at_commit
);

    localparam                          DEPTH = 2**depth_bits;
    localparam  bit [depth_bits-1:0]    FULL = '1;

    rvfi_data_t [DEPTH-1:0]            rvfi_data_arr; // RVFI data that will be in parallel to ROB entry

    // Internal ROB logic variables
    logic [depth_bits-1:0]    head_ptr_next;
    logic [63:0]              order;
    logic [63:0]              order_next;
    logic [depth_bits-1:0]    rob_count, rob_count_next;
    
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
pc_at_commit.branch_resol = rob_arr[tail_ptr].rd_data[0];
pc_at_commit.branch_inst = rob_arr[tail_ptr].branch_inst;
pc_at_commit.pred_branch_address = rob_arr[tail_ptr].branch_address;
pc_at_commit.pc = rob_arr[tail_ptr].pc;
pc_at_commit.ready = rob_arr[tail_ptr].ready;
pc_at_commit.valid = rob_arr[tail_ptr].valid;
pc_at_commit.jal_inst = rob_arr[tail_ptr].jal_inst;
end


always_comb begin

    // ROB full logic
    if (rob_count >= (FULL - 2'b10)) begin
        rob_full = 1'b1;
    end else begin
        rob_full = 1'b0;
    end
     
    // TODO: Fix for superscalar
    if (decode_rob_bus[0].ready) begin // && !rs_full) begin
    //     // Head ptr next is the previous pointer plus the number of valid instructions
    //     //for (int i = 0; i < decode_ports; i++) begin
        head_ptr_next = head_ptr + 1'b1;
           //end 
    end
    else begin
        head_ptr_next = head_ptr;
    end

    order_next = order + 1'b1; 

    // Commit and Dispatch
    if (((rob_arr[tail_ptr].ready && rob_arr[tail_ptr].valid) || (mem_rob_data_bus[0].ready && rob_arr[mem_rob_data_bus[0].rob_id].valid && mem_rob_data_bus[0].store)) && (decode_rob_bus[0].ready == 1'b1)) begin
        rob_count_next = rob_count;
    // Dispatch Only
    end else if (decode_rob_bus[0].ready == 1'b1) begin
        rob_count_next  = rob_count + 1'b1;
    // Commit only
    end else if ((rob_arr[tail_ptr].ready && rob_arr[tail_ptr].valid) || (mem_rob_data_bus[0].ready && rob_arr[mem_rob_data_bus[0].rob_id].valid && mem_rob_data_bus[0].store)) begin
        rob_count_next  = rob_count - 1'b1;
    //Neither
    end else begin
        rob_count_next  = rob_count;
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
        // COMMIT LOGIC
        ///////////////
        // Check if item at tail has op_complete == 1 -> Send out data to reg file and update tail
        if ((rob_arr[tail_ptr].ready && rob_arr[tail_ptr].valid) || (mem_rob_data_bus[0].ready && rob_arr[mem_rob_data_bus[0].rob_id].valid && mem_rob_data_bus[0].store)) begin
            
            // Put data on bus
            rob_reg_data_bus[0].ready <= 1'b1;
            rob_reg_data_bus[0].rd_data <= rob_arr[tail_ptr].rd_data;
            rob_reg_data_bus[0].rd_addr <= rob_arr[tail_ptr].rd_addr;
            rob_reg_data_bus[0].rob_id <= tail_ptr;
            // Update tail
            tail_ptr <= tail_ptr + 1'b1;
            // Invalidate tail
            rob_arr[tail_ptr].valid <= 1'b0;

            // Output RVFI
            if (rob_arr[tail_ptr].valid) begin
                rvfi_output.monitor_valid <= rvfi_data_arr[tail_ptr].monitor_valid;
                // Increment order only if valid commit
                order <= order_next;
            end
            else begin
                rvfi_output.monitor_valid <= 1'b0;
            end
            rvfi_output.monitor_order <= order; // Update order
            rvfi_output.monitor_inst <= rvfi_data_arr[tail_ptr].monitor_inst;
            rvfi_output.monitor_rs1_addr <= rvfi_data_arr[tail_ptr].monitor_rs1_addr;
            rvfi_output.monitor_rs2_addr <= rvfi_data_arr[tail_ptr].monitor_rs2_addr;
            rvfi_output.monitor_rs1_rdata <= rvfi_data_arr[tail_ptr].monitor_rs1_rdata;
            rvfi_output.monitor_rs2_rdata <= rvfi_data_arr[tail_ptr].monitor_rs2_rdata;
            rvfi_output.monitor_regf_we <= rvfi_data_arr[tail_ptr].monitor_regf_we;
            rvfi_output.monitor_rd_addr <= rvfi_data_arr[tail_ptr].monitor_rd_addr;
            rvfi_output.monitor_rd_wdata <= rvfi_data_arr[tail_ptr].monitor_rd_wdata;
            rvfi_output.monitor_pc_rdata <= rvfi_data_arr[tail_ptr].monitor_pc_rdata;
            rvfi_output.monitor_pc_wdata <= rvfi_data_arr[tail_ptr].monitor_pc_wdata;
            rvfi_output.monitor_mem_addr <= rvfi_data_arr[tail_ptr].monitor_mem_addr;
            rvfi_output.monitor_mem_rmask <= rvfi_data_arr[tail_ptr].monitor_mem_rmask;
            rvfi_output.monitor_mem_wmask <= rvfi_data_arr[tail_ptr].monitor_mem_wmask;
            rvfi_output.monitor_mem_rdata <= rvfi_data_arr[tail_ptr].monitor_mem_rdata;
            rvfi_output.monitor_mem_wdata <= rvfi_data_arr[tail_ptr].monitor_mem_wdata;

            // Branch instruction flush if prediction is incorrect
            // Case 1: Branch Misprediction
            // Case 2: Jump Instruction
			//Prediction was correct
            if ((rob_arr[tail_ptr].branch_inst &&
                (rob_arr[tail_ptr].branch_pred == rob_arr[tail_ptr].rd_data[0]))) begin
                branch_miss <= 1'b0;
                br_address  <= rob_arr[tail_ptr].rd_data[0] ? (rob_arr[tail_ptr].branch_address) : (rob_arr[tail_ptr].pc + 'd4);
            end
			else if ((rob_arr[tail_ptr].branch_inst &&
                (rob_arr[tail_ptr].branch_pred != rob_arr[tail_ptr].rd_data[0]))) begin
				branch_miss <= 1'b1;
				br_address <= rob_arr[tail_ptr].rd_data[0]? rob_arr[tail_ptr].branch_address : (rob_arr[tail_ptr].pc + 4);
				end
        
        else if(rob_arr[tail_ptr].jal_inst && rob_arr[tail_ptr].branch_pred) begin
            branch_miss <= 1'b0;
	          br_address  <= rob_arr[tail_ptr].branch_address;	
        end
        
         else if(rob_arr[tail_ptr].jal_inst && !rob_arr[tail_ptr].branch_pred) begin
            branch_miss <= 1'b1;
	          br_address  <= rob_arr[tail_ptr].branch_address;	
        end
        
				else if(rob_arr[tail_ptr].jump_inst && !rob_arr[tail_ptr].jal_inst) begin
					 branch_miss <= 1'b1;
					 br_address  <= rob_arr[tail_ptr].branch_address;	
				end
            else if (load_mispredict) begin
                branch_miss <= 1'b1;
                br_address  <= rob_arr[tail_ptr].pc + 'd4;
            end
            else begin
                branch_miss <= 1'b0;
            end

        end else begin
            // Set data on bus to invalid and 'x
            rob_reg_data_bus[0].ready <= 1'b0;
            rob_reg_data_bus[0].rd_data <= 'x;
            rob_reg_data_bus[0].rd_addr <= 'x;
            // Update tail
            tail_ptr <= tail_ptr;
            // Invalidate RVFI output if no new commit
            rvfi_output.monitor_valid <= 1'b0;
        end

        //////////////////////////
        // DECODE -> ROB BUS LOGIC
        //////////////////////////

        // Add new items from decode bus(es) into rob entries
        //for (logic [4:0] i = 5'b0; i < decode_ports; i++) begin
            if (decode_rob_bus[0].ready == 1'b1) begin
                rob_arr[head_ptr + 0].ready          <= 1'b0;
                rob_arr[head_ptr + 0].valid         <= 1'b1;
                rob_arr[head_ptr + 0].branch_inst   <= decode_rob_bus[0].branch_inst;
                rob_arr[head_ptr + 0].jump_inst     <= decode_rob_bus[0].jump_inst;
                rob_arr[head_ptr + 0].jal_inst     <= decode_rob_bus[0].jal_inst;
                rob_arr[head_ptr + 0].mem_inst      <= decode_rob_bus[0].mem_inst;
                rob_arr[head_ptr + 0].branch_pred  <= decode_rob_bus[0].branch_pred;
                rob_arr[head_ptr + 0].branch_address <= decode_rob_bus[0].branch_address;
                rob_arr[head_ptr + 0].pc            <= decode_rob_bus[0].pc;
                rob_arr[head_ptr + 0].rd_addr       <= decode_rob_bus[0].rd_addr;
                rob_arr[head_ptr + 0].rd_data       <= 'x;
                
                // Validate entry
                rob_arr[head_ptr + 0].valid <= 1'b1;
                
                rvfi_data_arr[head_ptr + 0] <= decode_rob_bus[0].rvfi_data;

                // Increment head pointer
                head_ptr <= head_ptr_next;
            end
        //end

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