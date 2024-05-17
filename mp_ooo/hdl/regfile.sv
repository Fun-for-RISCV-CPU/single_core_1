module regfile 
import rv32i_types::*;
#(parameter decode_ports = 1, parameter data_wb_ports = 1, parameter rob_depth_bits = 5)
(
    input   logic                                    clk,
    input   logic                                    rst,
    //input   logic                                    regf_we,
    //input   logic               [31:0]               rd_data,
    input   logic               [4:0]                rs1_addr, rs2_addr,
    input   logic               [rob_depth_bits-1:0] rob_head_ptr,
    input   decode_rob_bus_t    [decode_ports-1:0]   decode_rob_bus,
    input   rob_reg_data_bus_t  [data_wb_ports-1:0]  data_wb_bus,

    output  reg_file_op                              rs1_data, rs2_data
);
    // Internal Data Array
    // Entries
    // 1.Data [31:0]
    // 2.Rob_id [rob_depth_bits]
    // 3.Ready -> Indicates if RS should use reg data or ROB id. 1: Use data, 0: Use ROB id.
    reg_file_op   [31:0]    reg_file;

    // Sequential Updates to reg file
    always_ff @(posedge clk) begin
      // Reset
      if (rst) begin
            for (int i = 0; i < 32; i++) begin
                reg_file[i].rd_data <= '0;
                reg_file[i].rob_id <= 'x;
                reg_file[i].ready <= 1'b1;
            end
        end 

      
      else begin 

          // Always update ROB id with output from the decode stage and the ROB head ptr
          if (decode_rob_bus[0].ready) begin
            reg_file[decode_rob_bus[0].rd_addr].rob_id <= rob_head_ptr;
          end

          // Post Commit Update based on ROB Data
          if (data_wb_bus[0].ready && (data_wb_bus[0].rd_addr != 5'd0)) begin
            // Update the reg file data with the data from the commited instruction
            reg_file[data_wb_bus[0].rd_addr].rd_data <= data_wb_bus[0].rd_data;
          end
        
          // Logic for updating use ROB ready bit
          // Must be separate conditional to resolve case of simultaneous update to same address

          // Simultaneous Update
          if (decode_rob_bus[0].ready && data_wb_bus[0].ready && decode_rob_bus[0].rd_addr != '0) begin
              // Same address -> Decode takes precidence
              if ((decode_rob_bus[0].rd_addr == data_wb_bus[0].rd_addr)) begin
                // Update ready bit
                reg_file[decode_rob_bus[0].rd_addr].ready <= 1'b0;
              end
              // Different Addresses
              else begin
                // Update ready bit at decode addr
                reg_file[decode_rob_bus[0].rd_addr].ready <= 1'b0;

                // Update ready bit only if commited id is most recent id
                if (reg_file[data_wb_bus[0].rd_addr].rob_id == data_wb_bus[0].rob_id) begin
                  // Update ready bit at wb addr
                  reg_file[data_wb_bus[0].rd_addr].ready <= 1'b1;
                  end
              end
            end
          // Non-simultaneous Update
          else begin
            if (decode_rob_bus[0].ready && decode_rob_bus[0].rd_addr != '0 ) begin
              // Update ready bit
              reg_file[decode_rob_bus[0].rd_addr].ready <= 1'b0;
            end

            if (data_wb_bus[0].ready && (reg_file[data_wb_bus[0].rd_addr].rob_id == data_wb_bus[0].rob_id)) begin
              // Update ready bit at wb addr
              reg_file[data_wb_bus[0].rd_addr].ready <= 1'b1;
            end
          end
        end
    end

    always_comb begin
      // Transparent reg file
      if (data_wb_bus[0].ready &&  // Data on wb bus
          (data_wb_bus[0].rd_addr == rs1_addr) && //Address matches
          (data_wb_bus[0].rd_addr != 0) && //Dest is not reg 0
          (reg_file[data_wb_bus[0].rd_addr].rob_id == data_wb_bus[0].rob_id)) begin // Data being returned is most recent ROB id

        rs1_data.rd_data = data_wb_bus[0].rd_data;
        rs1_data.rob_id = 'x;
        rs1_data.ready = 1'b1;

      end else begin
        rs1_data = reg_file[rs1_addr];
      end
      
      if (data_wb_bus[0].ready &&  // Data on wb bus
          (data_wb_bus[0].rd_addr == rs2_addr) && //Address matches
          (data_wb_bus[0].rd_addr != 0) && //Dest is not reg 0
          (reg_file[data_wb_bus[0].rd_addr].rob_id == data_wb_bus[0].rob_id)) begin // Data being returned is most recent ROB id

        rs2_data.rd_data = data_wb_bus[0].rd_data;
        rs2_data.rob_id = 'x;
        rs2_data.ready = 1'b1;

      end else begin
        rs2_data = reg_file[rs2_addr];
      end
    end

endmodule : regfile