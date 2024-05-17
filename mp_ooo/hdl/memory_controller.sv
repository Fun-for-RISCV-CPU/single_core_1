module memory_controller
import rv32i_types::*;
#(parameter rob_depth_bits = ROB_ID_SIZE)
(
    input logic clk,
    input logic rst,
    input logic branch_mispredict,
    output mem_rob_data_bus_t mem_rob_data_o,
    input   logic   [31:0]  dmem_rdata,
    input   logic           dmem_resp,
    input ls_mem_bus_t mem_input,
    output logic [1:0] mem_state
);

logic [1:0] state_next;
ls_mem_bus_t mem_inp_intermediate;

always_ff @(posedge clk) begin
    if(rst || branch_mispredict) begin
        mem_state <= mem_idle;
        mem_inp_intermediate <= 'x;
    end
    else begin
        mem_state <= state_next;
        if(mem_input.valid == 1'b1) mem_inp_intermediate <= mem_input;
        else mem_inp_intermediate <= mem_inp_intermediate;
    end
end

always_comb begin
    state_next = mem_state;
    mem_rob_data_o.ready = 1'b0;
    mem_rob_data_o.rob_id = 'x;
    mem_rob_data_o.rd_data = 'x;
    mem_rob_data_o.dmem_rdata = 'x;
    mem_rob_data_o.store = 'x;
    
    case (mem_state)
    mem_idle: begin
        if(mem_input.valid) begin
        state_next = mem_resp_wait;
        end
        else state_next = mem_idle;
    end
    mem_resp_wait: begin
        if(dmem_resp) begin
            state_next = mem_idle;
            mem_rob_data_o.ready = 1'b1;
            mem_rob_data_o.rob_id = mem_inp_intermediate.rob_id;
            if(mem_inp_intermediate.dmem_wmask != '0) mem_rob_data_o.store = 1'b1;
            else if(mem_inp_intermediate.dmem_rmask != '0) begin
                mem_rob_data_o.store = 1'b0;
                mem_rob_data_o.dmem_rdata = dmem_rdata;
                unique case (mem_inp_intermediate.funct3)
                    lb : mem_rob_data_o.rd_data = {{24{dmem_rdata[7 +8 *mem_inp_intermediate.dmem_addr[1:0]]}}, dmem_rdata[8 *mem_inp_intermediate.dmem_addr[1:0] +: 8 ]};
                    lbu: mem_rob_data_o.rd_data = {{24{1'b0}}                          , dmem_rdata[8 *mem_inp_intermediate.dmem_addr[1:0] +: 8 ]};
                    lh : mem_rob_data_o.rd_data = {{16{dmem_rdata[15+16*mem_inp_intermediate.dmem_addr[1]  ]}}, dmem_rdata[16*mem_inp_intermediate.dmem_addr[1]   +: 16]};
                    lhu: mem_rob_data_o.rd_data = {{16{1'b0}}                          , dmem_rdata[16*mem_inp_intermediate.dmem_addr[1]   +: 16]};
                    lw : mem_rob_data_o.rd_data = dmem_rdata;
                    default: mem_rob_data_o.rd_data = 'x;
                endcase
            end
        end
        else begin
            state_next = mem_resp_wait;
        end
    end
    endcase

end
endmodule : memory_controller
