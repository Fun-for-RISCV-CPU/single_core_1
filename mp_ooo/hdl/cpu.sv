module cpu
import rv32i_types::*;
(
    // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
    input   logic           clk,
    input   logic           rst,

    output  logic   [31:0]  imem_addr,
    output  logic   [3:0]   imem_rmask,
    input   logic   [31:0]  imem_rdata,
    input   logic           imem_resp,

    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    input   logic   [31:0]  dmem_rdata,
    output  logic   [31:0]  dmem_wdata,
    input   logic           dmem_resp

    // Single memory port connection when caches are integrated into design (CP3 and after)
    /*
    output logic   [31:0]      bmem_addr,
    output logic               bmem_read,
    output logic               bmem_write,
    output logic   [63:0]      bmem_wdata,
    input logic               bmem_ready,

    input logic   [31:0]      bmem_raddr,
    input logic   [63:0]      bmem_rdata,
    input logic               bmem_rvalid
    */
);
    logic           branch_mispredict, in_flight_mem;
    logic  [1:0] mem_state;
    ls_mem_bus_t    mem_input;
    logic           valid_inst, load_mispredict;
    //full and empty for ls_q to be sent to decode
    logic           reservation_full, full_load, empty_load, full_store, empty_store;
    logic   [31:0]  branch_target; 
    logic   [EX_UNITS-1:0][31:0]  rvfi_rs1_v, rvfi_rs2_v;
    logic   [63:0]  inst_out;
    logic           dmem_dum;
    logic   [31:0]  dmem_rdata_dum;
    logic   [4:0]   rs1_addr, rs2_addr;
    // parametrize it later based on rob_depth
    logic   [ROB_ID_SIZE-1:0]  rob_tail_ptr, rob_head_ptr;
    logic                   rob_full;
    reg_file_op             rs1_data, rs2_data;
    // Size of these buses need to be updated for superscalarity
    decode_rob_bus_t  [0:0]  decode_rob_bus;
    inst_decode       decode_rs_bus;
    rob_reg_data_bus_t   [0:0]  data_wb_bus;
    rob_entry_t          [2**ROB_ID_SIZE-1:0] rob_data_bus;
    ex_data_bus_t     alu_data_bus[EX_UNITS];
    rs_d              rs_data[EX_UNITS];
    rvfi_data_t                                  rvfi_output;
    mem_rob_data_bus_t  mem_rob_data_o;
    ls_rob_data_bus_t   load_rob_data_bus, store_rob_data_bus;
    
    assign load_mispredict = 1'b0;
    
    
    //Need this to come from decode
    ls_q_entry        ls_q_o, ls_q_inst1;
    

    //assign branch_mispredict = 1'b0;
    //assign reservation_full = 1'b0;
    //assign branch_target = 'x;
   // assign dmem_dum = dmem_resp;
   // assign dmem_rdata_dum = dmem_rdata;
   // assign dmem_addr = 'x;
   // assign dmem_wdata = 'x;
   // assign dmem_rmask = 4'b0000;
   // assign dmem_wmask = 4'b0000;


    fetch_unit fetch_unit_inst(
        .clk(clk),
        .rst(rst),
        .branch_mispredict(branch_mispredict),
        .branch_target(branch_target),
        .imem_resp(imem_resp),
        .imem_rdata(imem_rdata),
        .reservation_full(reservation_full),
        .imem_addr(imem_addr),
        .imem_rmask(imem_rmask),
        .inst_out(inst_out),
        .valid_inst(valid_inst),
        .rob_full(rob_full)
    );
    
    decode decode(
    .clk(clk),
    .rst(rst),
    .branch_mispredict(branch_mispredict),
    .valid_inst(valid_inst),
    .queue_packet(inst_out),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .decode_rob_bus(decode_rob_bus),
    .decode_rs_bus(decode_rs_bus),
    .ls_q_inst1(ls_q_inst1),
    .rob_id_dest(rob_head_ptr)
    );
    
    regfile regfile(
    .clk(clk),
    .rst(rst),
    .branch_mispredict(branch_mispredict),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rob_head_ptr(rob_head_ptr),
    .decode_rob_bus(decode_rob_bus),   
    .data_wb_bus(data_wb_bus)
    );
    
    reservation_station  reservation_station(
    .clk(clk),
    .rst(rst),
    .branch_mispredict(branch_mispredict),
    .inst1(decode_rs_bus),
    .rob_id_dest(rob_head_ptr),
    .full(reservation_full),
    .rvfi_rs1_v(rvfi_rs1_v),
    .rvfi_rs2_v(rvfi_rs2_v),
    .rob_data_bus(rob_data_bus),
    .alu_data_bus(alu_data_bus),
    .rs_data(rs_data)
    );
    
    execution_stage  execution_stage(
        .clk(clk),
        .rst(rst),
        .rs_data(rs_data),
        .data_bus(alu_data_bus)
    );
    
    rob rob(
    .clk(clk),
    .rst(rst),
    .rvfi_rs1_v(rvfi_rs1_v),
    .rvfi_rs2_v(rvfi_rs2_v),
    .branch_miss(branch_mispredict),
    .br_address(branch_target),
    .ex_data_bus(alu_data_bus),
    .decode_rob_bus(decode_rob_bus),
    .mem_rob_data_bus(mem_rob_data_o),
    .load_rob_data_bus(load_rob_data_bus),
    .store_rob_data_bus(store_rob_data_bus),
    .load_mispredict(load_mispredict),
    .rob_arr(rob_data_bus),
    .head_ptr(rob_head_ptr),
    .rob_full(rob_full),
    .rob_reg_data_bus(data_wb_bus),
    .rvfi_output(rvfi_output),
    .tail_ptr(rob_tail_ptr)
    );
    
    load_store load_store(
    .clk(clk),
    .rst(rst),
    .branch_mispredict(branch_mispredict),
    .ls_q_inst1(ls_q_inst1),
    .rob_data_bus(rob_data_bus),
    .mem_state(mem_state),
    .rob_tail_ptr(rob_tail_ptr),
    .mem_input(mem_input),
    .full_store(full_store),
    .empty_store(empty_store),
    .full_load(full_load),
    .empty_load(empty_load),
    .load_rob_data_bus(load_rob_data_bus),
    .store_rob_data_bus(store_rob_data_bus)
    );
    
    memory_controller memory_controller(
    .clk(clk),
    .rst(rst),
    .branch_mispredict(branch_mispredict),
    // .ls_q_in1(ls_q_o),
    .mem_rob_data_o(mem_rob_data_o),
    .dmem_addr(dmem_addr),
    .dmem_rmask(dmem_rmask),
    .dmem_wmask(dmem_wmask),
    .dmem_rdata(dmem_rdata),
    .dmem_wdata(dmem_wdata),
    .dmem_resp(dmem_resp),
    .mem_state(mem_state),
    .mem_input(mem_input)
    );
    
    
endmodule : cpu
