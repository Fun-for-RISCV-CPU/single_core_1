module rob
import rv32i_types::*;
#(parameter depth_bits = 5, parameter decode_ports = 1, parameter ex_ports = 8, parameter data_wb_ports = 1)
(
    // Global inputs
    input logic                                         clk,
    input logic                                         rst,
    
    // Input ports
    input ex_data_bus_t                   ex_data_bus[ex_ports], // One data bus for for each execution unit
    input decode_rob_bus_t      [decode_ports-1:0]      decode_rob_bus, // Data bus directly from decode to ROB
    
    // Forwarded RS1 and RS2 values for RVFI
    input logic                 [ex_ports - 1:0][31:0]                  rvfi_rs1_v, rvfi_rs2_v,             

    // Broadcast data
    output rob_entry_t          [2**depth_bits-1:0]     rob_arr, // ROB array. Note that RVFI data is not included here
    output logic                [depth_bits-1:0]        head_ptr,
    output logic                                        rob_full,

    // Output ports
    output rob_reg_data_bus_t   [data_wb_ports-1:0]     rob_reg_data_bus,
    output rvfi_data_t                                  rvfi_output,
    output  logic [depth_bits-1:0]    tail_ptr
);

    localparam  DEPTH = 2**depth_bits;

    rvfi_data_t [DEPTH-1:0]            rvfi_data_arr; // RVFI data that will be in parallel to ROB entry
    logic       [2**depth_bits-1:0]    valid; 

    // Internal ROB logic variables
    logic [depth_bits-1:0]    head_ptr_next;
    logic [63:0]              order;
    logic [63:0]              order_next;

always_comb begin

    // ROB full logic
    if ((head_ptr_next == tail_ptr) && valid[head_ptr_next]) begin
        rob_full = 1'b1;
    end else begin
        rob_full = 1'b0;
    end
     
    // TODO: Fix for superscalar
    if (decode_rob_bus[0].ready) begin
    //     // Head ptr next is the previous pointer plus the number of valid instructions
    //     //for (int i = 0; i < decode_ports; i++) begin
        head_ptr_next = head_ptr + 1'b1;
           //end 
    end
    else begin
        head_ptr_next = head_ptr;
    end

    order_next = order + 1'b1; 
end

always_ff @(posedge clk) begin
    
    // Reset logic and head ptr update
    if (rst) begin
        head_ptr <= '0;
        tail_ptr <= '0;
        order    <= '0;
        rvfi_output <= '0;
        valid <= '0;
    end 
    else begin
        head_ptr <= head_ptr_next;

        // Check if item at tail has op_complete == 1 -> Send out data to reg file and update tail
        if (rob_arr[tail_ptr].ready == 1'b1) begin
            // Put data on bus
            rob_reg_data_bus[0].ready <= 1'b1;
            rob_reg_data_bus[0].rd_data <= rob_arr[tail_ptr].rd_data;
            rob_reg_data_bus[0].rd_addr <= rob_arr[tail_ptr].rd_addr;
            rob_reg_data_bus[0].rob_id <= tail_ptr;
            // Update tail
            tail_ptr <= tail_ptr + 1'b1;
            // Invalidate tail
            valid [tail_ptr] <= 1'b0;

            // Output RVFI
            rvfi_output.monitor_valid <= rvfi_data_arr[tail_ptr].monitor_valid;
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

            // Increment order
            order <= order_next;

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

        // Add new items from decode bus(es) into rob entries
        //for (logic [4:0] i = 5'b0; i < decode_ports; i++) begin
            if (decode_rob_bus[0].ready == 1'b1) begin
                rob_arr[head_ptr + 0].ready <= 1'b0;
                rob_arr[head_ptr + 0].branch <= decode_rob_bus[0].branch;
                rob_arr[head_ptr + 0].pc <= decode_rob_bus[0].pc;
                rob_arr[head_ptr + 0].rd_addr <= decode_rob_bus[0].rd_addr;
                rob_arr[head_ptr + 0].rd_data <= 'x;
                // Validate entry
                valid [head_ptr + 0] <= 1'b1;

                rvfi_data_arr[head_ptr + 0] <= decode_rob_bus[0].rvfi_data;
            end
        //end

        // Update items in ROB based on number of valid entries on data bus
        for (int i = 0; i < ex_ports; i++) begin
                    // Data on bus is valid, update the data field in the ROB entry and mark op_complete
            if (ex_data_bus[i].ready == 1) begin
                rob_arr[ex_data_bus[i].rob_id].rd_data <= ex_data_bus[i].rd_data; // Update rd_data field in the ROB
                rob_arr[ex_data_bus[i].rob_id].ready   <= 1'b1; // Set op_complete to 1

                // Update RVFI based on result of execution
                rvfi_data_arr[ex_data_bus[i].rob_id].monitor_rs1_rdata <= rvfi_rs1_v[i];
                rvfi_data_arr[ex_data_bus[i].rob_id].monitor_rs2_rdata <= rvfi_rs2_v[i];
                rvfi_data_arr[ex_data_bus[i].rob_id].monitor_rd_wdata  <= ex_data_bus[i].rd_data;
                rvfi_data_arr[ex_data_bus[i].rob_id].monitor_order     <= order;
            end
        end

    end

end

endmodule: rob