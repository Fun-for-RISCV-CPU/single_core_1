/////////////////////////////////////////////////////////////
//  Maybe use some of your types from mp_pipeline here?    //
//    Note you may not need to use your stage structs      //
/////////////////////////////////////////////////////////////
package cache_types; 
localparam OFFSET = 5;
localparam N_SET = 4;
localparam TAG_SIZE = 32-N_SET-OFFSET;
typedef enum bit [2:0] {
    idle = 3'b000,
    compare = 3'b001,
    allocate = 3'b010,
    write_back = 3'b011,
    cache_wait = 3'b100
} cache_states;

typedef enum bit [1:0] {
    adapter_idle = 2'b00,
    read = 2'b01,
    write = 2'b10,
    response = 2'b11
} adapter_states;

typedef enum bit {
    arb_idle = 1'b0,
    arb_write = 1'b1
} arbiter_states;

typedef struct packed{
    logic                       valid;
    logic   [TAG_SIZE-1:0]      tag;
    logic   [4:0]               offset;
    logic   [N_SET-1:0]         set;  
    logic   [3:0]               wmask;
    logic   [31:0]              wdata;
} cache_stage_reg_t;

typedef struct packed{
  logic   [31:0]  address;
  logic   [255:0] cache_line;
} pre_fetch_buffer_t;

endpackage

package rv32i_types;

    localparam  ROB_ID_SIZE = 4;
    localparam  EX_UNITS = 3;

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
        logic           branch_pred;
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
        logic                   valid; // Used to locate instructions that were in reservation stations but need to be flushed
        logic                   branch_inst;
        logic                   jump_inst;
        logic                   jal_inst;
        logic    mem_inst;
        logic                   branch_pred;
        logic   [31:0]          branch_address;
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
        logic                  branch_inst;
        logic                  jump_inst;
        logic                  jal_inst;
        logic    mem_inst;
        logic                  branch_pred;
        logic   [31:0]         branch_address;
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
        mulhu = 3'b011,
        div = 3'b100,
        divu = 3'b101,
        rem  = 3'b110,
        remu = 3'b111
    } mult_ops;
    
    typedef enum bit {
        div_idle  = 1'b0, //check bit 30 for sub if op_reg opcode
        div_compute  = 1'b1
    } div_state;
    
      typedef enum bit [2:0] {
        beq  = 3'b000,
        bne  = 3'b001,
        blt  = 3'b100,
        bge  = 3'b101,
        bltu = 3'b110,
        bgeu = 3'b111
    } branch_funct3_t;
    
    typedef enum bit [1:0] {
        snt  = 2'b00, //check bit 30 for sub if op_reg opcode
        wnt  = 2'b01,
        wt  = 2'b10,
        st = 2'b11
    } bimod_counter;
    
      typedef enum bit [3:0] {
        NT3  = 4'b0000, //check bit 30 for sub if op_reg opcode
        NT2  = 4'b0001,
        NT1  = 4'b0010,
        NT0  = 4'b0100,
        WT0  = 4'b0101,
        WT1 = 4'b0110,
        WT2 = 4'b0111,
        WT3 = 4'b1000
    } trimod_counter;
    
     typedef enum bit [1:0] {
        mem_idle  = 2'b00,
        rob_store_update  = 2'b01,
        mem_resp_wait = 2'b10
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
        // logic    pc_sel;
        // logic    rd_choice;    
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
        logic    [15:0]  age;
        logic    speculation_bit;
        logic    issued;
        logic    address_computed;
		logic    [31:0] dmem_addr;
    logic   ready_for_mem;
    logic    [31:0] dmem_wdata;
    logic    [3:0] dmem_wmask;
    logic      dmem_wdata_computed;
      } ls_q_entry;
      
      typedef struct packed{
        logic                   ready;
        logic                   valid;
        logic   [ROB_ID_SIZE-1:0] rob_id;
        logic   [31:0]          rd_data;
        logic   [31:0]          dmem_rdata;
        logic   [31:0]          dmem_wdata;
        logic   [31:0]          dmem_addr;
        logic   [3:0]          dmem_rmask;
        logic   [3:0]          dmem_wmask;
         logic   [31:0]          rs1_v;
        logic   [31:0]          rs2_v;
        
      } ls_rob_data_bus_t;
	  
	  typedef struct packed{
        logic   [ROB_ID_SIZE-1:0] rob_id;
        logic   [31:0]          dmem_wdata;
        logic   [31:0]          dmem_addr;
        logic   [3:0]          dmem_rmask;
        logic   [3:0]          dmem_wmask;
		logic   [2:0]          funct3;
		logic					valid;
    logic         flush;
      }ls_mem_bus_t;
	  
	    typedef struct packed{
        logic   [ROB_ID_SIZE-1:0] rob_id_dest;
        logic   [31:0]          dmem_wdata;
        logic   [31:0]          dmem_addr;
        logic   [3:0]          dmem_wmask;
		logic					valid;
		logic					store_flush;
		logic					in_flight;
		logic	[15:0]			age;
      }store_buffer_entry;

 typedef struct packed{
        logic   [ROB_ID_SIZE-1:0] rob_id_dest;
        logic   [31:0]          dmem_rdata;
        logic   [31:0]          rd_data;
		logic   [31:0]          rs1_v;
        logic   [3:0]          dmem_rmask;
        logic   [2:0]          funct3;
		logic					valid;
		logic	[15:0]			age;
		logic    [31:0] dmem_addr;
  logic      ready_for_mem;
  logic      data_forwarded;
      }load_res_station_entry;
      
       typedef struct packed{
        logic   [ROB_ID_SIZE-1:0] rob_id_dest;
        logic   [31:0]          dmem_wdata;
        logic   [31:0]          rd_data;
		logic   [31:0]          rs1_v;
   logic   [31:0]          rs2_v;
        logic   [3:0]          dmem_wmask;
        logic   [2:0]          funct3;
		logic					valid;
		logic	[15:0]			age;
		logic    [31:0] dmem_addr;
      }store_res_station_entry;
      
	  
	   typedef struct packed{
        logic                   ready;
        logic   [ROB_ID_SIZE-1:0] rob_id;
        logic   [31:0]          rd_data;
        logic   [31:0]          dmem_rdata;
        logic                   store;
      } mem_rob_data_bus_t;
      

		
			typedef struct packed{
    logic [31:0] pc;
		logic	branch_resol;
		logic	branch_inst;
    logic  jal_inst;
   logic ready;
   logic valid;
		logic	[31:0] pred_branch_address;
		} rob_to_btb_bus;
		
		typedef struct packed{
		logic 	[31:0] pred_address;
		logic	[31:0] pc;
		logic	[1:0] bimod_counter;
    logic	[3:0] trimod_counter;
		} btb_entry;

endpackage
