module ls_forwarding
import rv32i_types::*;
#(parameter rob_depth_bits = ROB_ID_SIZE)
(
    input logic [3:0] rmask,
    input logic [2:0] funct3,
    input logic [3:0] wmask,
    input logic [31:0] wdata,
    input logic [31:0] dmem_addr,
    output   logic   [31:0]  rdata,
    output   logic   [31:0]  rd_data,
    output   logic   data_forwarded
);

always_comb begin
        rdata = 'x;
        rd_data = 'x;
        data_forwarded = 1'b0;
        case (rmask)
            4'b0001: begin
                if((wmask == 4'b1111) || (wmask == 4'b0011) || (wmask == 4'b0001)) begin
                    rdata = wdata;
                    data_forwarded = 1'b1;
                    case (funct3)
                        lb: rd_data = {{24{wdata[7 +8 *dmem_addr[1:0]]}}, rdata[8 *dmem_addr[1:0] +: 8 ]};
                        lbu: rd_data = {{24{1'b0}}  , wdata[8 *dmem_addr[1:0] +: 8 ]};
                    endcase
                end
            end
            4'b0010: begin
                      if((wmask == 4'b1111) || (wmask == 4'b0011) || (wmask == 4'b0010)) begin
                    rdata = wdata;
                    data_forwarded = 1'b1;
                    case (funct3)
                        lb: rd_data = {{24{wdata[7 +8 *dmem_addr[1:0]]}}, rdata[8 *dmem_addr[1:0] +: 8 ]};
                        lbu: rd_data = {{24{1'b0}}  , wdata[8 *dmem_addr[1:0] +: 8 ]};
                    endcase
                end
            end
            
            4'b0100: begin
                      if((wmask == 4'b1111) || (wmask == 4'b1100) || (wmask == 4'b0100)) begin
                    rdata = wdata;
                    data_forwarded = 1'b1;
                    case (funct3)
                        lb: rd_data = {{24{wdata[7 +8 *dmem_addr[1:0]]}}, rdata[8 *dmem_addr[1:0] +: 8 ]};
                        lbu: rd_data = {{24{1'b0}}  , wdata[8 *dmem_addr[1:0] +: 8 ]};
                    endcase
                end
            end
            
              4'b1000: begin
                      if((wmask == 4'b1111) || (wmask == 4'b1100) || (wmask == 4'b1000)) begin
                    rdata = wdata;
                    data_forwarded = 1'b1;
                    case (funct3)
                        lb: rd_data = {{24{wdata[7 +8 *dmem_addr[1:0]]}}, rdata[8 *dmem_addr[1:0] +: 8 ]};
                        lbu: rd_data = {{24{1'b0}}  , wdata[8 *dmem_addr[1:0] +: 8 ]};
                    endcase
                end
            end
            
             4'b0011: begin
                      if((wmask == 4'b1111) || (wmask == 4'b0011)) begin
                    rdata = wdata;
                    data_forwarded = 1'b1;
                    case (funct3)
                        lh: rd_data = {{16{wdata[15+16*dmem_addr[1]  ]}}, wdata[16*dmem_addr[1]   +: 16]};
                        lhu: rd_data = {{16{1'b0}}                          , wdata[16*dmem_addr[1]   +: 16]};
                    endcase
                end
            end
            
            4'b1100: begin
                      if((wmask == 4'b1111) || (wmask == 4'b1100)) begin
                    rdata = wdata;
                    data_forwarded = 1'b1;
                    case (funct3)
                        lh: rd_data = {{16{wdata[15+16*dmem_addr[1]  ]}}, wdata[16*dmem_addr[1]   +: 16]};
                        lhu: rd_data = {{16{1'b0}}                          , wdata[16*dmem_addr[1]   +: 16]};
                    endcase
                end
            end
            
             4'b1111: begin
                      if((wmask == 4'b1111)) begin
                    rdata = wdata;
                    data_forwarded = 1'b1;
                    rd_data = wdata;
                end
            end
            
        endcase    
end

endmodule: ls_forwarding