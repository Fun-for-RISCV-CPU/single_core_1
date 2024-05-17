module reservation_station
import rv32i_types::*;
#(parameter size = EX_UNITS, parameter rob_size = ROB_ID_SIZE)
(
    input logic clk,
    input logic rst,
    input logic branch_mispredict,
    //input logic load_inst1,
    input inst_decode [SS_DISPATCH_WIDTH - 1:0]  inst1,
    input logic [SS_DISPATCH_WIDTH - 1:0][rob_size-1:0]      rob_id_dest,
    input rob_entry_t [2**rob_size-1:0] rob_data_bus,
    input ex_data_bus_t alu_data_bus[size],
    output logic full,
    output rs_d rs_data[size],
    output logic[size - 1:0][31:0] rvfi_rs1_v, rvfi_rs2_v

);

//Inputs explanation
//load_inst1 tells the reservation stations that some instruction needs to be loaded in from the instruction queue, we can increase the width of this signal for superscalarity
//inst1  is the decoded instruction with all the fields that might be needed by the execution unit - its defined in types
//rob_id and rob_id2 are the two rob_ids sent by the decoder based on wherever the to inputs might be coming from, if coming from the rob..they can be dont cares for the instruction that has no dependeny
//rob_data_bus is the o/p coming from rob to the reservation station..defined in types
//alu_data_bus is the o/p from the ex units to the rob and reservation station

//Outputs explanation
//output logic full tells the decoder that all reservation stations are full..do not dequeue anything
//rs_data is the o/p of the reservation station to be used by the ex units
//rvfi_rs1_v and rvfi_rs2_v have correct values for rvfi source operands

// Size of rs limited to 32
logic [1:0][4:0] next_rs;
logic rs_idx;

int busy_stations;
// Logic to find out which reservation station is free.
//If no reservation station is free next_rs (Index of the next reservation station will be -1 except begining of the program)

always_comb begin
    next_rs = '1;
    rvfi_rs1_v = 'x;
    rvfi_rs2_v = 'x;
    busy_stations = 0;
    full = 1'b0;

    rs_idx = 1'b0;
    for (int i=0; i < size; i++) begin
        if(rs_data[i].valid == 1'b0 && !rs_idx) begin
            next_rs[rs_idx] = 5'(i);
            rs_idx = 1'b1;
        end else if (rs_data[i].valid == 1'b0 && rs_idx) begin
            next_rs[rs_idx] = 5'(i);
        end
    end
    
    for(int k=0; k < size; k++) begin
      if(rs_data[k].valid == 1'b1) busy_stations = busy_stations + 1;
      
      if(alu_data_bus[k].ready) begin
      if(rs_data[k].opcode != op_b_imm) begin
          rvfi_rs1_v[k] = rs_data[k].rs1_v;
          rvfi_rs2_v[k] = rs_data[k].rs2_v;
      end
      else begin
           rvfi_rs1_v[k] = rs_data[k].rs1_v;
           rvfi_rs2_v[k] = '0;
      end
      end
      
      else begin
          rvfi_rs1_v[k] = 'x;
          rvfi_rs1_v[k] = 'x;
      end
      
    end
    
    if((busy_stations == size-3 && (inst1[0].valid || inst1[1].valid)) || (busy_stations == size-2 && (inst1[0].valid || inst1[1].valid)) || busy_stations == size-1 || busy_stations == size) full = 1'b1;

end

always_ff @(posedge clk) begin
    // rst signal clears all the data in rservation station
    // Flush all stations on mispredict
    if (rst || branch_mispredict) begin
        for(int i=0; i < size; i++) begin
            rs_data[i].valid <= '0;
            rs_data[i].rs1_v <= 'x;
            rs_data[i].rs2_v <= 'x;
            rs_data[i].rob_id <= 'x;
            rs_data[i].rob_id2 <= 'x;
            rs_data[i].rob_id_dest <= 'x;
            rs_data[i].r1 <= '0;
            rs_data[i].r2 <= '0;
        end
    end
    else begin
    //Check if something needs to be loaded
    //alu_cmp signal tells you if you need to check alu or cmp for op_reg and op_imm instructions
    // rs_data[next_rs].r1 or  rs_data[next_rs].r2 signals signify that the operands are available
    //rd_choice signal tells if you want to choose usual alu output or a modified output for slt and sltu instruction
    //pc_sel signifies if you want to choose pc + 4 or modified pc..used in jal, jalr and branch inst
    
        for (int i = 0; i < SS_DISPATCH_WIDTH; i++) begin
            if(inst1[i].valid)begin
                rs_data[next_rs[i]].rob_id <= inst1[i].rs1.rob_id;
                rs_data[next_rs[i]].rob_id2 <= inst1[i].rs2.rob_id;
                rs_data[next_rs[i]].valid <= inst1[i].valid;
                rs_data[next_rs[i]].opcode <= inst1[i].opcode;
                rs_data[next_rs[i]].funct7 <= inst1[i].funct7;
                rs_data[next_rs[i]].alu_cmp <= 1'b0;
                rs_data[next_rs[i]].rob_id_dest <= rob_id_dest[i];
                rs_data[next_rs[i]].funct3 <= inst1[i].funct3;
                //rd_data[next_rs].rd_choice <= 1'b0;
                unique case (inst1[i].opcode)
                
                op_b_lui: begin
                //Pass through the alu and add 0 to u_imm
                    rs_data[next_rs[i]].aluop <= alu_add;
                    rs_data[next_rs[i]].rs1_v <= inst1[i].u_imm;
                    rs_data[next_rs[i]].rs2_v <= 32'd0;
                    //rs_data[next_rs + i].busy <= 1'b1;
                    rs_data[next_rs[i]].r1 <= 1'b1;
                    rs_data[next_rs[i]].r2 <= 1'b1;
                    rs_data[next_rs[i]].alu_cmp <= 1'b0;
                    //rs_data[next_rs + i].rd_choice <= 1'b0;
                    //rs_data[next_rs + i].pc_sel <= 1'b0;
                end 

                op_b_auipc: begin
                    //rs_data[next_rs + i].opcode <= op_b_reg;
                    rs_data[next_rs[i]].aluop <= alu_add;
                    rs_data[next_rs[i]].rs1_v <= inst1[i].pc;
                    rs_data[next_rs[i]].rs2_v <= inst1[i].u_imm;
                    //rs_data[next_rs + i].busy <= 1'b1;
                    rs_data[next_rs[i]].r1 <= 1'b1;
                    rs_data[next_rs[i]].r2 <= 1'b1;
                    rs_data[next_rs[i]].alu_cmp <= 1'b0;
                    //rs_data[next_rs + i].rd_choice <= 1'b0;
                    //rs_data[next_rs + i].pc_sel <= 1'b0;
                end

                op_b_imm: begin                
                    rs_data[next_rs[i]].rs2_v <= inst1[i].i_imm;
                    //rs_data[next_rs + i].busy <= 1'b1;
                    rs_data[next_rs[i]].r2 <= 1'b1;
                    //rs_data[next_rs + i].pc_sel <= 1'b0;
                    // Here you check if regfile has data which is ready
                    if(inst1[i].rs1.ready) begin
                        rs_data[next_rs[i]].rs1_v <= inst1[i].rs1.rd_data;
                        rs_data[next_rs[i]].r1 <= 1'b1;
                    end
                    // If data in regfile is not ready then check the rob
                    else begin
                        if(rob_data_bus[inst1[i].rs1.rob_id].ready && rob_data_bus[inst1[i].rs1.rob_id].valid) begin
                            rs_data[next_rs[i]].rs1_v <= rob_data_bus[inst1[i].rs1.rob_id].rd_data;
                            rs_data[next_rs[i]].r1 <= 1'b1;
                        end
                        else begin
                        //if we dont have a data there too, just wait..reolving these is discussed later..
                            rs_data[next_rs[i]].rs1_v <= 'x;
                            rs_data[next_rs[i]].r1 <= 1'b0;
                        end
                    end
                    unique case (inst1[i].funct3)
                    slt: begin
                        rs_data[next_rs[i]].alu_cmp <= 1'b1;
                        //rs_data[next_rs + i].rd_choice <= 1'b0;
                        rs_data[next_rs[i]].cmpop <= blt;
                    end
                    sltu: begin
                        rs_data[next_rs[i]].alu_cmp <= 1'b1;
                        //rs_data[next_rs + i].rd_choice <= 1'b0;
                        rs_data[next_rs[i]].cmpop <= bltu;
                    end
                    sr: begin
                        rs_data[next_rs[i]].alu_cmp <= 1'b0;
                        //rs_data[next_rs + i].rd_choice <= 1'b0;
                        if (inst1[i].funct7[5]) begin
                            rs_data[next_rs[i]].aluop <= alu_sra;
                        end else begin
                            rs_data[next_rs[i]].aluop <= alu_srl;
                        end
                    end
                    default: begin
                        rs_data[next_rs[i]].alu_cmp <= 1'b0;
                        //rs_data[next_rs + i].rd_choice <= 1'b0;
                        rs_data[next_rs[i]].aluop <= inst1[i].funct3;    
                    end
                    endcase
                end

                op_b_reg: begin
                    //rs_data[next_rs + i].busy <= 1'b1;
                    //rs_data[next_rs + i].pc_sel <= 1'b0;
                    if(inst1[i].rs1.ready) begin
                        rs_data[next_rs[i]].rs1_v <= inst1[i].rs1.rd_data;
                        rs_data[next_rs[i]].r1 <= 1'b1;
                    end
                    else begin
                        if(rob_data_bus[inst1[i].rs1.rob_id].ready && rob_data_bus[inst1[i].rs1.rob_id].valid) begin
                            rs_data[next_rs[i]].rs1_v <= rob_data_bus[inst1[i].rs1.rob_id].rd_data;
                            rs_data[next_rs[i]].r1 <= 1'b1;
                        end
                        else begin
                            rs_data[next_rs[i]].rs1_v <= 'x;
                            rs_data[next_rs[i]].r1 <= 1'b0;
                        end
                    end

                    if(inst1[i].rs2.ready) begin
                        rs_data[next_rs[i]].rs2_v <= inst1[i].rs2.rd_data;
                        rs_data[next_rs[i]].r2 <= 1'b1;
                    end
                    else begin
                        if(rob_data_bus[inst1[i].rs2.rob_id].ready && rob_data_bus[inst1[i].rs2.rob_id].valid) begin
                            rs_data[next_rs[i]].rs2_v <= rob_data_bus[inst1[i].rs2.rob_id].rd_data;
                            rs_data[next_rs[i]].r2 <= 1'b1;
                        end
                        else begin
                            rs_data[next_rs[i]].rs2_v <= 'x;
                            rs_data[next_rs[i]].r2 <= 1'b0;
                        end
                    end

                    unique case (inst1[i].funct3)
                    slt: begin
                        rs_data[next_rs[i]].alu_cmp <= 1'b1;
                        // rs_data[next_rs + i].rd_choice <= 1'b0;
                        rs_data[next_rs[i]].cmpop <= blt;
                    end
                    sltu: begin
                        rs_data[next_rs[i]].alu_cmp <= 1'b1;
                        // rs_data[next_rs + i].rd_choice <= 1'b0;
                        rs_data[next_rs[i]].cmpop <= bltu;
                    end
                    sr: begin
                        rs_data[next_rs[i]].alu_cmp <= 1'b0;
                        // rs_data[next_rs + i].rd_choice <= 1'b0;
                        if (inst1[i].funct7[5]) begin
                            rs_data[next_rs[i]].aluop <= alu_sra;
                        end else begin
                            rs_data[next_rs[i]].aluop <= alu_srl;
                        end
                    end
                    add: begin
                        rs_data[next_rs[i]].alu_cmp <= 1'b0;
                        // rs_data[next_rs + i].rd_choice <= 1'b0;
                        if (inst1[i].funct7[5]) begin
                            rs_data[next_rs[i]].aluop <= alu_sub;
                        end else begin
                            rs_data[next_rs[i]].aluop <= alu_add;
                        end
                    end
                    default: begin
                        rs_data[next_rs[i]].alu_cmp <= 1'b0;
                        // rs_data[next_rs + i].rd_choice <= 1'b0;
                        rs_data[next_rs[i]].aluop <= inst1[i].funct3;    
                    end
                    endcase
                    
                end

                op_b_jal: begin
                    //rs_data[next_rs + i].pc_sel <= 1'b1; // ??
                    rs_data[next_rs[i]].aluop <= alu_add;
                    rs_data[next_rs[i]].rs1_v <= inst1[i].pc;
                    rs_data[next_rs[i]].rs2_v <= inst1[i].j_imm;
                    rs_data[next_rs[i]].r1 <= 1'b1;
                    rs_data[next_rs[i]].r2 <= 1'b1;
                    rs_data[next_rs[i]].alu_cmp <= 1'b0;
                end

                op_b_jalr: begin
                    //rs_data[next_rs + i].pc_sel <= 1'b1;
                    rs_data[next_rs[i]].aluop <= alu_add;
                    rs_data[next_rs[i]].rs2_v <= inst1[i].i_imm;
                    rs_data[next_rs[i]].r2 <= 1'b1;
                    rs_data[next_rs[i]].alu_cmp <= 1'b0;
                    // rs_data[next_rs + i].rd_choice <= 1'b1;
                    if(inst1[i].rs1.ready) begin
                        rs_data[next_rs[i]].rs1_v <= inst1[i].rs1.rd_data;
                        rs_data[next_rs[i]].r1 <= 1'b1;
                    end
                    else begin
                        if(rob_data_bus[inst1[i].rs1.rob_id].ready && rob_data_bus[inst1[i].rs1.rob_id].valid) begin
                            rs_data[next_rs[i]].rs1_v <= rob_data_bus[inst1[i].rs1.rob_id].rd_data;
                            rs_data[next_rs[i]].r1 <= 1'b1;
                        end
                        else begin
                            rs_data[next_rs[i]].rs1_v <= 'x;
                            rs_data[next_rs[i]].r1 <= 1'b0;
                        end
                    end
                end

                op_b_br: begin
                    rs_data[next_rs[i]].cmpop <= inst1[i].funct3;
                    //rs_data[next_rs + i].pc_sel <= 1'b1;
                    rs_data[next_rs[i]].alu_cmp <= 1'b1; // Do compare function

                    if(inst1[i].rs1.ready) begin
                        rs_data[next_rs[i]].rs1_v <= inst1[i].rs1.rd_data;
                        rs_data[next_rs[i]].r1 <= 1'b1;
                    end
                    else begin
                        if(rob_data_bus[inst1[i].rs1.rob_id].ready && rob_data_bus[inst1[i].rs1.rob_id].valid) begin
                            rs_data[next_rs[i]].rs1_v <= rob_data_bus[inst1[i].rs1.rob_id].rd_data;
                            rs_data[next_rs[i]].r1 <= 1'b1;
                        end
                        else begin
                            rs_data[next_rs[i]].rs1_v <= 'x;
                            rs_data[next_rs[i]].r1 <= 1'b0;
                        end
                    end

                    if(inst1[i].rs2.ready) begin
                        rs_data[next_rs[i]].rs2_v <= inst1[i].rs2.rd_data;
                        rs_data[next_rs[i]].r2 <= 1'b1;
                    end
                    else begin
                        if(rob_data_bus[inst1[i].rs2.rob_id].ready && rob_data_bus[inst1[i].rs2.rob_id].valid) begin
                            rs_data[next_rs[i]].rs2_v <= rob_data_bus[inst1[i].rs2.rob_id].rd_data;
                            rs_data[next_rs[i]].r2 <= 1'b1;
                        end
                        else begin
                            rs_data[next_rs[i]].rs2_v <= 'x;
                            rs_data[next_rs[i]].r2 <= 1'b0;
                        end
                    end

                end

                default: begin
                end
                endcase
            end
        end
    end
    
    //Here every cycle you check if something has been resolved from the ROB or the alu data bus
    
    for(int i=0; i < size; i++) begin
        if((rs_data[i].r1 == 1'b0) && (rob_data_bus[rs_data[i].rob_id].ready) && rs_data[i].valid) begin
            rs_data[i].rs1_v <= rob_data_bus[rs_data[i].rob_id].rd_data;
            rs_data[i].r1 <= 1'b1;
        end

        if((rs_data[i].r2 == 1'b0) && (rob_data_bus[rs_data[i].rob_id2].ready) && rs_data[i].valid) begin
            rs_data[i].rs2_v <= rob_data_bus[rs_data[i].rob_id2].rd_data;
            rs_data[i].r2 <= 1'b1;
        end
    end

    for(int i=0; i < size; i++) begin
        if((rs_data[i].r1 == 1'b0) && (alu_data_bus[i].ready) && rs_data[i].valid && (alu_data_bus[i].rob_id == rs_data[i].rob_id)) begin
            rs_data[i].rs1_v <= alu_data_bus[i].rd_data;
            rs_data[i].r1 <= 1'b1;
        end

        if((rs_data[i].r2 == 1'b0) && (alu_data_bus[i].ready) && rs_data[i].valid && (alu_data_bus[i].rob_id == rs_data[i].rob_id2)) begin
            rs_data[i].rs2_v <= alu_data_bus[i].rd_data;
            rs_data[i].r2 <= 1'b1;
        end
    end
    
    //If the computation is complete, you need to invalidate the reservation station, so that decode knows it is free

    for (int j = 0; j < SS_DISPATCH_WIDTH; j++) begin
        for (int i = 0; i< size; i++) begin
            if(alu_data_bus[i].ready && ~(inst1[j].valid && (next_rs[j] == 5'(i)))) begin
            // rvfi_rs1_v <= rs_data[i].rs1_v;
                // rvfi_rs2_v <= rs_data[i].rs2_v;
                rs_data[i].valid <= '0;
                rs_data[i].rs1_v <= '0;
                rs_data[i].rs2_v <= '0;
                rs_data[i].rob_id <= 'x;
                rs_data[i].rob_id2 <= 'x;
                rs_data[i].rob_id_dest <= 'x;
                rs_data[i].r1 <= '0;
                rs_data[i].r2 <= '0;
            end
        end
    end

end
endmodule : reservation_station
