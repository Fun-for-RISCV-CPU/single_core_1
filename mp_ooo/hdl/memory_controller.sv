module memory_controller
import rv32i_types::*;
#(parameter rob_depth_bits = 5)
(
    input logic clk,
    input logic rst,
    input ls_q_entry ls_q_in1,
    output mem_rob_data_bus mem_rob_data_o,
    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    input   logic   [31:0]  dmem_rdata,
    output  logic   [31:0]  dmem_wdata,
    input   logic           dmem_resp,
    output  logic           in_flight_mem,
    input   logic   [rob_depth_bits - 1:0] tail_ptr

);

logic [1:0] state, state_next;
ls_q_entry ls_q_intermediate;
logic [31:0] intermediate_addr;

assign intermediate_addr = ls_q_intermediate.rs1_v + ls_q_intermediate.ls_imm;
always_ff @(posedge clk) begin
    if(rst) begin
        state <= mem_idle;
        ls_q_intermediate <= 'x;
    end
    else begin
        state <= state_next;
        if(ls_q_in1.valid && ls_q_in1.mem_inst) ls_q_intermediate <= ls_q_in1;
        else ls_q_intermediate <= ls_q_intermediate;
    end
end

always_comb begin
    state_next = state;
    mem_rob_data_o.ready = 1'b0;
    mem_rob_data_o.rob_id = 'x;
    mem_rob_data_o.rd_data = 'x;
    dmem_rmask = '0;
    dmem_wmask = '0;
    dmem_addr = 'x;
    dmem_wdata = 'x;
    in_flight_mem = '0;
    case (state)
    mem_idle: begin
        in_flight_mem = '0;
        if(ls_q_in1.valid) begin
            if(ls_q_in1.l_s) state_next = mem_req;
            else state_next = mem_store_wait;
        end
        else state_next = mem_idle;
    end
    mem_store_wait: begin
        in_flight_mem = 1'b1;
        if(tail_ptr == ls_q_intermediate.rob_id_dest) state_next = mem_req;
        else state_next = mem_store_wait;
    end
    
    mem_req: begin
        in_flight_mem = 1'b1;
        dmem_addr = {intermediate_addr[31:2],2'b00};
        dmem_wdata = 'x;
        case (ls_q_intermediate.l_s)
        1'b1: begin
            dmem_wdata = 'x;
            unique case (ls_q_intermediate.funct3)
                    lb, lbu: dmem_rmask = 4'b0001 << intermediate_addr[1:0];
                    lh, lhu: dmem_rmask = 4'b0011 << intermediate_addr[1:0];
                    lw:      dmem_rmask = 4'b1111;
                    default: dmem_rmask = 'x;
                endcase
            state_next = mem_resp_wait;
        end

        1'b0: begin
            unique case (ls_q_intermediate.funct3)
                    sb: dmem_wmask = 4'b0001 <<  intermediate_addr[1:0];
                    sh: dmem_wmask = 4'b0011 <<  intermediate_addr[1:0];
                    sw: dmem_wmask = 4'b1111;
                    default: dmem_wmask = 'x;
                endcase
                unique case (ls_q_intermediate.funct3)
                    sb: dmem_wdata[8 * intermediate_addr[1:0] +: 8 ] = ls_q_intermediate.rs2_v[7 :0];
                    sh: dmem_wdata[16* intermediate_addr[1]   +: 16] = ls_q_intermediate.rs2_v[15:0];
                    sw: dmem_wdata = ls_q_intermediate.rs2_v;
                    default: dmem_wdata = 'x;
                endcase
                state_next = mem_resp_wait;
        end
        endcase
    end

    mem_resp_wait: begin
        in_flight_mem = 1'b1;
        if(dmem_resp) begin
            state_next = mem_idle;
            if(ls_q_intermediate.l_s) begin
                unique case (ls_q_intermediate.funct3)
                    lb : mem_rob_data_o.rd_data = {{24{dmem_rdata[7 +8 *intermediate_addr[1:0]]}}, dmem_rdata[8 *intermediate_addr[1:0] +: 8 ]};
                    lbu: mem_rob_data_o.rd_data = {{24{1'b0}}                          , dmem_rdata[8 *intermediate_addr[1:0] +: 8 ]};
                    lh : mem_rob_data_o.rd_data = {{16{dmem_rdata[15+16*intermediate_addr[1]  ]}}, dmem_rdata[16*intermediate_addr[1]   +: 16]};
                    lhu: mem_rob_data_o.rd_data = {{16{1'b0}}                          , dmem_rdata[16*intermediate_addr[1]   +: 16]};
                    lw : mem_rob_data_o.rd_data = dmem_rdata;
                    default: mem_rob_data_o.rd_data = 'x;
                endcase
                mem_rob_data_o.ready = 1'b1;
                mem_rob_data_o.rob_id = ls_q_intermediate.rob_id_dest;
            end

            else begin
                mem_rob_data_o.ready = 1'b1;
                mem_rob_data_o.rob_id = ls_q_intermediate.rob_id_dest; 
                mem_rob_data_o.rd_data = 'x;
            end

        end

        else begin
            state_next = mem_resp_wait;
        end
    end

    endcase

end
endmodule : memory_controller
