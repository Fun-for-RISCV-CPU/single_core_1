module decode
import rv32i_types::*;
#(parameter rob_size = 5)
(
    input   logic                       valid_inst,
    input   logic    [63:0]             queue_packet,
    input   reg_file_op                 rs1_data, rs2_data,
    output   logic   [4:0]               rs1_addr, rs2_addr,
    output  decode_rob_bus_t            decode_rob_bus,
    output  inst_decode                 decode_rs_bus,
    output  ls_q_entry                  ls_q_inst1,
    input    logic  [rob_size-1:0]      rob_id_dest
);
    logic   [31:0]      rs1_d; // register data 1 
    logic   [31:0]      rs2_d; // register data 2

    logic   [4:0]       rs1_s; // register source addr 1
    logic   [4:0]       rs2_s; // register source addr 2
    logic   [31:0]      inst;

    logic   [2:0]       funct3;
    logic   [6:0]       funct7;
    logic   [6:0]       opcode;
    logic   [31:0]      i_imme;
    logic   [31:0]      s_imme;
    logic   [31:0]      b_imme;
    logic   [31:0]      u_imme;
    logic   [31:0]      j_imme;
    logic   [31:0]      imme;

    logic branch;

    logic   [4:0]   rd_addr;
    logic           regf_we;   

    // get pc from queue packet
    logic [31:0]    pc;
    assign pc = queue_packet[63:32];

    // Get inst from packet
    assign inst = queue_packet[31:0];

    // Decode info
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];
    assign opcode = inst[6:0];

    assign i_imme  = {{21{inst[31]}}, inst[30:20]};
    assign s_imme  = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    assign b_imme  = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    assign u_imme  = {inst[31:12], 12'h000};
    assign j_imme  = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    assign rs1_s  = inst[19:15];
    assign rs2_s  = inst[24:20];

    // Get data from reg_file
    //assign rs1_addr = rs1_s;
    //assign rs2_addr = rs2_s;

    // Route to reservation station
    assign decode_rs_bus.valid = valid_inst;
    assign decode_rs_bus.opcode = opcode;
    assign decode_rs_bus.funct7 = funct7;
    assign decode_rs_bus.funct3 = funct3;
    assign decode_rs_bus.u_imm = u_imme;
    assign decode_rs_bus.j_imm = j_imme;
    assign decode_rs_bus.i_imm = i_imme;
    assign decode_rs_bus.pc = pc;
    assign decode_rs_bus.rs1 = rs1_data;
    assign decode_rs_bus.rs2 = rs2_data;


    // Route to rob 
    assign decode_rob_bus.ready = valid_inst;
    assign decode_rob_bus.branch = {1'b0, branch};
    assign decode_rob_bus.pc = pc;
    assign decode_rob_bus.rd_addr = rd_addr;
    
    // Route to rob for rvfi
    assign decode_rob_bus.rvfi_data.monitor_valid       = valid_inst;
    assign decode_rob_bus.rvfi_data.monitor_inst        = inst;
    assign decode_rob_bus.rvfi_data.monitor_order       = 'x;
    assign decode_rob_bus.rvfi_data.monitor_rs1_addr    = rs1_addr;
    assign decode_rob_bus.rvfi_data.monitor_rs2_addr    = rs2_addr;
    assign decode_rob_bus.rvfi_data.monitor_rs1_rdata   = 'x;
    assign decode_rob_bus.rvfi_data.monitor_rs2_rdata   = 'x;
    assign decode_rob_bus.rvfi_data.monitor_regf_we     = regf_we;
    assign decode_rob_bus.rvfi_data.monitor_rd_addr     = rd_addr;
    assign decode_rob_bus.rvfi_data.monitor_rd_wdata    = 'x;
    assign decode_rob_bus.rvfi_data.monitor_pc_rdata    = pc;

    // TODO change later when branch or later stage will change
    assign decode_rob_bus.rvfi_data.monitor_pc_wdata    = pc + 'd4;

    // TODO change later for when load store are added
    assign decode_rob_bus.rvfi_data.monitor_mem_addr    = 'x;
    assign decode_rob_bus.rvfi_data.monitor_mem_rmask   = 4'b0000;
    assign decode_rob_bus.rvfi_data.monitor_mem_wmask   = 4'b0000;
    assign decode_rob_bus.rvfi_data.monitor_mem_rdata    = 'x;
    assign decode_rob_bus.rvfi_data.monitor_mem_wdata    = 'x;
                

    always_comb begin
        
        rs1_addr = rs1_s;
        rs2_addr = rs2_s;
        regf_we = 1'b0;
        branch = 1'b0;
        ls_q_inst1.mem_inst = 1'b0;
        ls_q_inst1.l_s = 'x;
        ls_q_inst1.r1 = 'x;
        ls_q_inst1.r2 = 'x;
        ls_q_inst1.ls_imm = 'x;
        ls_q_inst1.rs1_v = 'x;
        ls_q_inst1.rs2_v = 'x;
        ls_q_inst1.rob_id = 'x;
        ls_q_inst1.rob_id2 = 'x;
        ls_q_inst1.valid = valid_inst;
        ls_q_inst1.funct3 = funct3;
        ls_q_inst1.rob_id_dest = rob_id_dest;

        rd_addr = inst[11:7];
        // Get branch info and rd for rob and rvfi
        unique case (opcode)
            op_b_lui: begin
                rs1_addr = '0;
                rs2_addr = '0;
                regf_we = 1'b1;
            end
            op_b_auipc: begin
                rs1_addr = '0;
                rs2_addr = '0;
                regf_we = 1'b1;
            end
            op_b_jal: begin
                rs1_addr = '0;
                rs2_addr = '0;
                regf_we = 1'b1;
            end
            op_b_jalr: begin
                rs2_addr = '0;
                regf_we = 1'b1;
            end
            op_b_br : begin
                branch = 1'b1;
                rd_addr = 'x;
                regf_we = 1'b1;
            end
            op_b_load: begin
                rs2_addr = '0;
                regf_we = 1'b1;
                ls_q_inst1.mem_inst = 1'b1;
                ls_q_inst1.l_s = 1'b1;
                ls_q_inst1.r1 = rs1_data.ready;
                ls_q_inst1.r2 = 1'b1;
                ls_q_inst1.ls_imm = i_imme;
                ls_q_inst1.rs1_v = rs1_data.rd_data;
                ls_q_inst1.rs2_v = 'x;
                ls_q_inst1.rob_id = rs1_data.rob_id;
                ls_q_inst1.rob_id2 = 'x;
                
                
            end
            op_b_store : begin
                regf_we = 1'b1;
                rd_addr = 'x;
                ls_q_inst1.mem_inst = 1'b1;
                ls_q_inst1.l_s = 1'b0;
                ls_q_inst1.r1 = rs1_data.ready;
                ls_q_inst1.r2 = rs2_data.ready;
                ls_q_inst1.ls_imm = s_imme;
                ls_q_inst1.rs1_v = rs1_data.rd_data;
                ls_q_inst1.rs2_v = rs2_data.rd_data;
                ls_q_inst1.rob_id = rs1_data.rob_id;
                ls_q_inst1.rob_id2 = rs2_data.rob_id;
                
		        branch = 1'b0;
            end
            op_b_imm: begin
                rs2_addr = '0;
                regf_we = 1'b1;
            end
            op_b_reg: begin
                regf_we = 1'b1;
            end
            op_b_csr: begin
                regf_we = 1'b0;
            end
            default: begin
                regf_we = 1'b1;
                branch = 1'b0;
                rd_addr = inst[11:7];
            end
        endcase
    end 

endmodule : decode
