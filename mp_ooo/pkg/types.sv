/////////////////////////////////////////////////////////////
//  Maybe use some of your types from mp_pipeline here?    //
//    Note you may not need to use your stage structs      //
/////////////////////////////////////////////////////////////

package rv32i_types;

    localparam  ROB_ID_SIZE = 5;

    typedef enum logic [6:0] {
        op_b_lui   = 7'b0110111, // U load upper immediate 
        op_b_auipc = 7'b0010111, // U add upper immediate PC 
        op_b_jal   = 7'b1101111, // J jump and link 
        op_b_jalr  = 7'b1100111, // I jump and link register 
        op_b_br    = 7'b1100011, // B branch 
        op_b_load  = 7'b0000011, // I load 
        op_b_store = 7'b0100011, // S store 
        op_b_imm   = 7'b0010011, // I arith ops with register/immediate operands 
        op_b_reg   = 7'b0110011, // R arith ops with register operands same as multiply
        op_b_csr   = 7'b1110011  // I control and status register 
    } rv32i_op_b_t;

    // action alias for inst queue
    typedef enum logic [1:0] {
        none        = 2'b00
        ,push       = 2'b01
        ,pop   = 2'b10
        ,push_pop        = 2'b11
    } action_t;

    // Branch prediction alias
    typedef enum logic{
        not_taken   = 1'b0,
        taken       = 1'b1
    } branch_pred_struct;

    typedef struct packed{
        logic           valid;
        logic   [31:0]  pc;
    } fetch_reg_1_t;

    // Struct for passing/updating RVFI info
    typedef struct packed{
        logic           monitor_valid;
        logic   [63:0]  monitor_order;
        logic   [31:0]  monitor_inst;
        logic   [4:0]   monitor_rs1_addr;
        logic   [4:0]   monitor_rs2_addr;
        logic   [31:0]  monitor_rs1_rdata;
        logic   [31:0]  monitor_rs2_rdata;
        logic           monitor_regf_we;
        logic   [4:0]   monitor_rd_addr;
        logic   [31:0]  monitor_rd_wdata;
        logic   [31:0]  monitor_pc_rdata;
        logic   [31:0]  monitor_pc_wdata;
        logic   [31:0]  monitor_mem_addr;
        logic   [3:0]   monitor_mem_rmask;
        logic   [3:0]   monitor_mem_wmask;
        logic   [31:0]  monitor_mem_rdata;
        logic   [31:0]  monitor_mem_wdata;
      } rvfi_data_t;

      // Op_complete (ready)
      typedef struct packed{
        logic                   ready; // Operation complete
        logic   [1:0]           branch;
        //logic   [ROB_ID_SIZE-1:0] rob_id;
        logic   [31:0]          pc;
        logic   [4:0]           rd_addr;
        logic   [31:0]          rd_data;
      }rob_entry_t;

      typedef struct packed{
        logic                   ready;
        logic   [ROB_ID_SIZE-1:0] rob_id;
        logic   [31:0]          rd_data;
      } ex_data_bus_t;

      typedef struct packed{
        logic                  ready;
        logic   [1:0]          branch;
        logic   [31:0]         pc;
        logic   [4:0]          rd_addr;
        rvfi_data_t            rvfi_data;
      } decode_rob_bus_t;

    //   typedef struct packed{
    //     logic                    valid;
    //     logic   [ROB_DEPTH-1:0]  rob_id;
    //     logic   [4:0]            rd_addr;
    //   } rob_reg_id_bus_t;

      typedef struct packed{
        logic                    ready;
        logic   [ROB_ID_SIZE-1:0]  rob_id;
        logic   [31:0]           rd_data;
        logic   [4:0]            rd_addr;
      } rob_reg_data_bus_t;

    // Add more things here . . .
    
    typedef enum bit [2:0] {
        add  = 3'b000, //check bit 30 for sub if op_reg opcode
        sll  = 3'b001,
        slt  = 3'b010,
        sltu = 3'b011,
        axor = 3'b100,
        sr   = 3'b101, //check bit 30 for logical/arithmetic
        aor  = 3'b110,
        aand = 3'b111
    } arith_funct3_t;

    typedef enum bit [2:0] {
        alu_add = 3'b000,
        alu_sll = 3'b001,
        alu_sra = 3'b010,
        alu_sub = 3'b011,
        alu_xor = 3'b100,
        alu_srl = 3'b101,
        alu_or  = 3'b110,
        alu_and = 3'b111
    } alu_ops;
    
    typedef enum bit [2:0] {
        lb  = 3'b000,
        lh  = 3'b001,
        lw  = 3'b010,
        lbu = 3'b100,
        lhu = 3'b101
    } load_funct3_t;

    typedef enum bit [2:0] {
        sb = 3'b000,
        sh = 3'b001,
        sw = 3'b010
    } store_funct3_t;

    typedef enum bit [2:0] {
        mul = 3'b000,
        mulh = 3'b001,
        mulhsu = 3'b010,
        mulhu = 3'b011
    } mult_ops;
    
      typedef enum bit [2:0] {
        beq  = 3'b000,
        bne  = 3'b001,
        blt  = 3'b100,
        bge  = 3'b101,
        bltu = 3'b110,
        bgeu = 3'b111
    } branch_funct3_t;
    
     typedef enum bit [1:0] {
        mem_idle  = 2'b00,
        mem_req  = 2'b01,
        mem_resp_wait  = 2'b10,
        mem_store_wait  = 2'b11
    } mem_controller_states;
    
    typedef struct packed{
        logic   [ROB_ID_SIZE-1:0]            rob_id;
        logic   [ROB_ID_SIZE-1:0]            rob_id2;
        logic   [ROB_ID_SIZE-1:0]            rob_id_dest;
        logic valid;
        logic   [6:0]    opcode;
        logic   [6:0]    funct7;
        logic   [2:0]    funct3;
        logic    alu_cmp;
        logic    [31:0] rs1_v;
        logic    [31:0] rs2_v;
        logic    [2:0]  aluop;
        logic    [2:0]  cmpop;
        logic    r1;
        logic    r2;
        logic    pc_sel;
        logic    rd_choice;    
      } rs_d;
      
      typedef struct packed{
      logic   [31:0]                rd_data;
      logic                         ready;
      logic   [ROB_ID_SIZE-1:0]     rob_id;
      }reg_file_op;
      
      typedef struct packed{
        logic valid;
        logic   [6:0]    opcode;
        logic   [6:0]    funct7;
        logic    [31:0] u_imm;
        logic    [31:0] j_imm;
        logic    [31:0] i_imm;
        logic    [31:0] pc;
        logic    [2:0] funct3;
        reg_file_op  rs1;
        reg_file_op  rs2;
      } inst_decode;

// This is the form of struct needed for load_store_queue, ls_imm would the immediate value to be added to rs1_v (s_imm for store, i_imm for load)
//for store send different elements for rs2 struct from regfile, for load, just send dont cares for rs2_v and r2 as 1
//mem_inst - instruction is a memory instruction
//l_s - 1'b1 for load, 1'b0 for store
      
      typedef struct packed{
        logic   [ROB_ID_SIZE-1:0]            rob_id;
        logic   [ROB_ID_SIZE-1:0]            rob_id2;
        logic   [ROB_ID_SIZE-1:0]            rob_id_dest;
        logic valid;
        logic   [2:0]    funct3;
        logic    [31:0] rs1_v;
        logic    [31:0] rs2_v;
        logic    r1;
        logic    r2;
        logic    l_s;
        logic    [31:0] ls_imm;
        logic    mem_inst;
      } ls_q_entry;
      
          typedef struct packed{
        logic                   ready;
        logic   [ROB_ID_SIZE-1:0] rob_id;
        logic   [31:0]          rd_data;
      } mem_rob_data_bus;


endpackage
