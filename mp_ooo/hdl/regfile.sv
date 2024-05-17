module regfile 
import rv32i_types::*;
#(parameter decode_ports = SS_DISPATCH_WIDTH, parameter data_wb_ports = COMMIT_FACTOR, parameter rob_depth_bits = ROB_ID_SIZE)
(
    input   logic                                    clk,
    input   logic                                    rst,
    input   logic                                    branch_mispredict,
    //input   logic                                    regf_we,
    //input   logic               [31:0]               rd_data,
    input   logic               [SS_DISPATCH_WIDTH - 1:0][4:0]                rs1_addr, rs2_addr,
    input   logic               [rob_depth_bits-1:0] rob_head_ptr,
    input   decode_rob_bus_t    [decode_ports-1:0]   decode_rob_bus,
    input   rob_reg_data_bus_t  [data_wb_ports-1:0]  data_wb_bus,

    output  reg_file_op         [SS_DISPATCH_WIDTH - 1:0]                     rs1_data, rs2_data
);
    // Internal Data Array
    // Entries
    // 1.Data [31:0]
    // 2.Rob_id [rob_depth_bits]
    // 3.Ready -> Indicates if RS should use reg data or ROB id. 1: Use data, 0: Use ROB id.
    reg_file_op   [31:0]    reg_file;

    logic         [data_wb_ports-1:0]  most_recent_wb_inst; // Detects for which channels in writeback should have write permission
    logic         [decode_ports-1:0]   most_recent_dec_inst; // Detects for which channels in decode should have write permission

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
        /////////////////
        // ROB ID ASSIGNMENT FROM DECODE BUS
        ///////////////// 
        // Always update ROB id with output from the decode stage and the ROB head ptr (if it is the most recent inst)
        // Sequential ROB ids
        for (int i = 0; i < decode_ports; i++) begin
          if (decode_rob_bus[i].ready && most_recent_dec_inst[i]) begin
            reg_file[decode_rob_bus[i].rd_addr].rob_id <= rob_head_ptr + rob_depth_bits'(i);
          end
        end

        /////////////////
        // DATA WRITE BACK FROM ROB
        ///////////////// 
        for (int i = 0; i < data_wb_ports; i++) begin
          // Post Commit Update based on ROB Data
          if (data_wb_bus[i].ready && (data_wb_bus[i].rd_addr != 5'd0) && most_recent_wb_inst[i]) begin
            // Update the reg file data with the data from the commited instruction
            reg_file[data_wb_bus[i].rd_addr].rd_data <= data_wb_bus[i].rd_data;
          end
        end
        
        /////////////////
        // READY BIT RESOLUTION
        ///////////////// 
        // Make all ready if flush due to branch
        if (branch_mispredict) begin
          for (int i = 0; i < 32; i++) begin
            reg_file[i].ready <= 1'b1;
          end
        end
        else begin

          // Update Decode Rob ID
          if (decode_rob_bus[0].ready && decode_rob_bus[0].rd_addr != '0) begin
            reg_file[decode_rob_bus[0].rd_addr].ready <= 1'b0;
          end

          // Update Decode Rob ID
          if (decode_rob_bus[1].ready && decode_rob_bus[1].rd_addr != '0) begin
            reg_file[decode_rob_bus[1].rd_addr].ready <= 1'b0;
          end

          for (int i = 0; i < data_wb_ports; i++) begin
              // Non-simultaneous Update
              if ((decode_rob_bus[1].rd_addr != data_wb_bus[i].rd_addr || !decode_rob_bus[1].ready) && 
                  (decode_rob_bus[0].rd_addr != data_wb_bus[i].rd_addr || !decode_rob_bus[0].ready) &&
                  reg_file[data_wb_bus[i].rd_addr].rob_id == data_wb_bus[i].rob_id && data_wb_bus[i].ready && data_wb_bus[i].rd_addr != '0) begin
                // Update ready bit only if commited id is most recent id
                // Update ready bit at wb addr
                reg_file[data_wb_bus[i].rd_addr].ready <= 1'b1;   
              end
          end
        end
      end
    end

always_comb begin

  // logic decode0_conflict;
  // logic decode1_conflict;

  // for (int i = 0; i < data_wb_ports; i++) begin
  //   if (decode_rob_bus[0].rd_addr == data_wb_bus[i].rd_addr) begin
  //     decode0_conflict = 1'b1;
  //     break;
  //   end else decode0_conflict = 1'b0;
  // end

  // for (int i = 0; i < data_wb_ports; i++) begin
  //   if (decode_rob_bus[1].rd_addr == data_wb_bus[i].rd_addr) begin
  //     decode1_conflict = 1'b1;
  //     break;
  //   end else decode1_conflict = 1'b0;
  // end

  // Transparent reg file

  // Case of dependent simultaneous decode
  if (rs1_addr[1] == decode_rob_bus[0].rd_addr && decode_rob_bus[0].rd_addr != 0) begin
    rs1_data[1].rob_id = rob_head_ptr;
    rs1_data[1].ready = 1'b0;
    rs1_data[1].rd_data = 'x;
    
    // Normal case for first decoded inst
    // Foward value from wb
    for (int i = 0; i < data_wb_ports; i++) begin
      if (data_wb_bus[i].ready &&  // Data on wb bus
      (data_wb_bus[i].rd_addr == rs1_addr[0]) && //Address matches
      (data_wb_bus[i].rd_addr != 0) && //Dest is not reg 0
      (reg_file[data_wb_bus[i].rd_addr].rob_id == data_wb_bus[i].rob_id)) begin // Data being returned is most recent ROB id

        rs1_data[0].rd_data = data_wb_bus[i].rd_data;
        rs1_data[0].rob_id = 'x;
        rs1_data[0].ready = 1'b1;

      // Value from regfile
      end else begin
        rs1_data[0] = reg_file[rs1_addr[0]];
      end
    end        
  end else begin
    for (int j = 0; j < decode_ports; j++) begin
      for (int i = 0; i < data_wb_ports; i++) begin
        // Foward value from wb
        if (data_wb_bus[i].ready &&  // Data on wb bus
            (data_wb_bus[i].rd_addr == rs1_addr[j]) && //Address matches
            (data_wb_bus[i].rd_addr != 0) && //Dest is not reg 0
            (reg_file[data_wb_bus[i].rd_addr].rob_id == data_wb_bus[i].rob_id)) begin // Data being returned is most recent ROB id

          rs1_data[j].rd_data = data_wb_bus[i].rd_data;
          rs1_data[j].rob_id = 'x;
          rs1_data[j].ready = 1'b1;

        // Value from regfile
        end else begin
          rs1_data[j] = reg_file[rs1_addr[j]];
        end
      end
    end
  end

  // Case of dependent simultaneous decode
  if (rs2_addr[1] == decode_rob_bus[0].rd_addr && decode_rob_bus[0].rd_addr != 0) begin
    rs2_data[1].rob_id = rob_head_ptr;
    rs2_data[1].ready = 1'b0;
    rs2_data[1].rd_data = 'x;
    
    // Normal case for first decoded inst
    // Foward value from wb
    for (int i = 0; i < data_wb_ports; i++) begin
      if (data_wb_bus[i].ready &&  // Data on wb bus
      (data_wb_bus[i].rd_addr == rs2_addr[0]) && //Address matches
      (data_wb_bus[i].rd_addr != 0) && //Dest is not reg 0
      (reg_file[data_wb_bus[i].rd_addr].rob_id == data_wb_bus[i].rob_id)) begin // Data being returned is most recent ROB id

        rs2_data[0].rd_data = data_wb_bus[i].rd_data;
        rs2_data[0].rob_id = 'x;
        rs2_data[0].ready = 1'b1;

      // Value from regfile
      end else begin
        rs2_data[0] = reg_file[rs2_addr[0]];
      end
    end        
  end else begin
    for (int j = 0; j < decode_ports; j++) begin
      for (int i = 0; i < data_wb_ports; i++) begin
        // Foward value from wb
        if (data_wb_bus[i].ready &&  // Data on wb bus
            (data_wb_bus[i].rd_addr == rs2_addr[j]) && //Address matches
            (data_wb_bus[i].rd_addr != 0) && //Dest is not reg 0
            (reg_file[data_wb_bus[i].rd_addr].rob_id == data_wb_bus[i].rob_id)) begin // Data being returned is most recent ROB id

          rs2_data[j].rd_data = data_wb_bus[i].rd_data;
          rs2_data[j].rob_id = 'x;
          rs2_data[j].ready = 1'b1;

        // Value from regfile
        end else begin
          rs2_data[j] = reg_file[rs2_addr[j]];
        end
      end
    end
  end






  // Multi-commit - same destination resolution logic
  // Loop over ports and determine collisions. Then set older instructions to zero so they do not write to reg file
  most_recent_wb_inst = '1;
  for (int i = 0; i < data_wb_ports - 1; i++) begin
    for (int j = i+1; j < data_wb_ports - 1; j++) begin
      if (data_wb_bus[i].rd_addr == data_wb_bus[j].rd_addr && data_wb_bus[j].ready && data_wb_bus[i].ready) begin
          most_recent_wb_inst[i] = 1'b0; // Collision - set lower index to zero so it does not write
      end
    end
  end

  // Multi-dispatch - same destination resolution logic
  // Loop over ports and determine collisions. Then set older instructions to zero so they do not write to reg file
  most_recent_dec_inst = '1;
  for (int i = 0; i < decode_ports - 1; i++) begin
    for (int j = i+1; j < decode_ports - 1; j++) begin
      if (decode_rob_bus[i].rd_addr == decode_rob_bus[j].rd_addr && decode_rob_bus[j].ready && decode_rob_bus[i].ready) begin
          most_recent_dec_inst[i] = 1'b0; // Collision - set lower index to zero so it does not write
      end
    end
  end



end

endmodule : regfile