module cmp
import rv32i_types::*;
(
    input   logic   [2:0]   cmpop,
    input   logic   [31:0]  a, b,
    output  logic           br_en
);

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin
        unique case (cmpop)
            beq:  br_en = (au == bu);
            bne:  br_en = (au != bu);
            blt:  br_en = (as <  bs);
            bge:  br_en = (as >=  bs);
            bltu: br_en = (au <  bu);
            bgeu: br_en = (au >=  bu);
            default: br_en = 1'bx;
        endcase
    end

endmodule: cmp

module alu
import rv32i_types::*;
(
    input   logic   [2:0]   aluop,
    input   logic   [31:0]  a, b,
    output  logic   [31:0]  f
);

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin
        unique case (aluop)
            alu_add: f = au +   bu;
            alu_sll: f = au <<  bu[4:0];
            alu_sra: f = unsigned'(as >>> bu[4:0]);
            alu_sub: f = au -   bu;
            alu_xor: f = au ^   bu;
            alu_srl: f = au >>  bu[4:0];
            alu_or:  f = au |   bu;
            alu_and: f = au &   bu;
            default: f = 'x;
        endcase
    end

endmodule : alu


module execution_unit
import rv32i_types::*;
(   
    input logic clk,
    input logic rst,
    input rs_d rs_data,
    output  mult_inst_bit,
    output  done_inst,
    output start_inst,
    output ex_data_bus_t data_bus
);
    logic   [2:0]   aluop;
    logic   [31:0]  alu_in_1;
    logic   [31:0]  alu_in_2;
    logic   [31:0]  alu_out;

    logic   [2:0]   cmpop;
    logic   [31:0]  cmp_in_1;
    logic   [31:0]  cmp_in_2;
    logic           cmp_out;
    logic   [31:0]  out;

    logic   [2:0]   funct3;
    logic           done;
    logic           start;
    logic   [63:0]  mul_out;
    logic           mult_inst;
    logic           mul_out_top;
    logic           ready;
    logic   [1:0]   mul_type;
    logic   [31:0]  mul_in_1;
    logic   [31:0]  mul_in_2;
    logic valid;
    // Signals for divider
    logic div_inst, start_div, div_complete, state_div, state_div_next,complete, divide_by_zero, divider_bypass_check;
    logic [31:0] div_inp_a, div_inp_b, quotient, remainder, quotient2, remainder2;
    
    always_comb begin
        div_inp_a = rs_data.rs1_v;
        div_inp_b = rs_data.rs2_v;
        case (funct3)
            div: begin
                div_inp_a = is_neg(rs_data.rs1_v) ? negative(rs_data.rs1_v) : rs_data.rs1_v;
                div_inp_b = is_neg(rs_data.rs2_v) ? negative(rs_data.rs2_v) : rs_data.rs2_v;
            end
            
            rem: begin
                 div_inp_a = is_neg(rs_data.rs1_v) ? negative(rs_data.rs1_v) : rs_data.rs1_v;
                 div_inp_b = is_neg(rs_data.rs2_v) ? negative(rs_data.rs2_v) : rs_data.rs2_v;
            end
        endcase
    
    end
    
    //Diver stuff
    assign divider_bypass_check = divider_bypass(div_inp_a, div_inp_b);
    assign div_complete = complete || divide_by_zero;

    assign done_inst = done;
    assign start_inst = start;
    // logic cmp_alu_mux;

    // assign cmp_alu_mux = rs_data.alu_cmp;
    assign funct3 = rs_data.funct3;

    assign aluop = rs_data.aluop;
    assign cmpop = rs_data.cmpop;

    assign alu_in_1 = rs_data.rs1_v;
    assign alu_in_2 = rs_data.rs2_v;

    assign cmp_in_1 = rs_data.rs1_v;
    assign cmp_in_2 = rs_data.rs2_v;

    assign mul_in_1 = rs_data.rs1_v;
    assign mul_in_2 = rs_data.rs2_v;

    assign data_bus.ready = ready;
    assign data_bus.rob_id = rs_data.rob_id_dest;
    assign data_bus.rd_data = out;

    assign mult_inst_bit = mult_inst;

    assign valid = rs_data.r1 && rs_data.r2;
    alu alu_inst(
        .aluop(aluop),
        .a(alu_in_1),
        .b(alu_in_2),
        .f(alu_out)
    );

    cmp cmp_inst(
        .cmpop(cmpop),
        .a(cmp_in_1),
        .b(cmp_in_2),
        .br_en(cmp_out)
    );

    shift_add_multiplier shift_add(
        .clk(clk),
        .rst(rst),
        .start(start),
        .mul_type(mul_type),
        .a(mul_in_1),
        .b(mul_in_2),
        .p(mul_out),
        .done(done)
    );
    
    divider divider(
    .inst_clk(clk),
    .inst_rst_n(~rst),
    .inst_hold(1'b0),
    .inst_start(start_div),
    .inst_a(div_inp_a),
    .inst_b(div_inp_b),
    .complete_inst(complete),
    .divide_by_0_inst(divide_by_zero),
    .quotient_inst(quotient),
    .remainder_inst(remainder)
    );
    
    
    always_ff @(posedge clk) begin
    if(rst) begin
        state_div <= div_idle;
    end
    else begin
        state_div <= state_div_next;
    end
    end
    
    always_comb begin
        state_div_next = state_div;
        start_div = 1'b0;
        case (state_div)
            div_idle: begin
                state_div_next = (div_inst && valid && rs_data.r1 && rs_data.r2 && ~divider_bypass_check) ? div_compute : div_idle;
                start_div = (div_inst && valid && rs_data.r1 && rs_data.r2 && ~divider_bypass_check) ? 1'b1: 1'b0;
            end
            
            div_compute: begin
                state_div_next = (div_inst && valid && rs_data.r1 && rs_data.r2 && div_complete) ? div_idle : div_compute;
                start_div = 1'b0;
            end
            
        endcase
    
    end
    always_comb begin
         // The instruction is multiply or divide
        mult_inst = 1'b0;
        div_inst = 1'b0;
        if (rs_data.opcode == op_b_reg && rs_data.funct7 == 7'b0000001 && valid && ((funct3 == mul) || (funct3 == mulh) || (funct3 ==mulhsu) || (funct3 == mulhu))) begin
            mult_inst = 1'b1;
        end
        
        if (rs_data.opcode == op_b_reg && rs_data.funct7 == 7'b0000001 && valid && ((funct3 == div) || (funct3 == divu) || (funct3 == rem) || (funct3 == remu))) begin
            div_inst = 1'b1;
        end

        if (mult_inst && valid) begin   
            ready = done && rs_data.r1 && rs_data.r2;
            start = (rs_data.r1 && rs_data.r2) || done;
        end
        
        else if(div_inst && valid) begin
            ready = ~divider_bypass_check && valid && rs_data.r1 && rs_data.r2 && div_complete && !start_div || divider_bypass_check && valid && rs_data.r1 && rs_data.r2;
            start = 1'b0;
            
        end
        else begin
            ready =  rs_data.r1 && rs_data.r2;
            start = 1'b0;      
        end

        unique case (funct3)
            mul : begin
                mul_type = 2'b01;
                mul_out_top = 1'b0;
            end
            mulh : begin
                mul_type = 2'b01;
                mul_out_top = 1'b1;
            end
            mulhsu : begin
                mul_type = 2'b10;
                mul_out_top = 1'b1;
            end
            mulhu : begin
                mul_type = 2'b00;
                mul_out_top = 1'b1;
            end
            default : begin
                mul_type = 2'bx;
                mul_out_top = 1'bx;
            end
        endcase

        // output mux for compare op reg instuction
        if (rs_data.alu_cmp == 1'b1) begin
            out = {31'd0, cmp_out};
        end 
        else if (mult_inst) begin
            out = mul_out[31:0];
            if (mul_out_top) begin
                out = mul_out[63:32];
            end
            else begin
                out = mul_out[31:0];
            end
        end
        
        else if(div_inst) begin
            case (funct3)
              div: begin
                  if(divider_bypass_check) begin
                        if(div_inp_b == 0) 
                            out = 32'h80000000;
                        else
                          out = ((is_neg(div_inp_a)) ^ (is_neg(div_inp_a))) ? negative(quotient2) : quotient2; 
                  end
                  else begin
                      case (divide_by_zero)
                          1'b1: begin
                            out = 32'h80000000;
                          end
                          1'b0: begin
                          out = ((is_neg(div_inp_a)) ^ (is_neg(div_inp_a))) ? negative(quotient) : quotient;   
                          end
                      endcase
                  end
              end
              
              rem: begin
                   if(divider_bypass_check) begin
                        out = ((is_neg(div_inp_a)) ^ (is_neg(div_inp_a))) ? negative(remainder2) : remainder2;
                   end
                   else begin
                       case (divide_by_zero)
                          1'b1: begin
                            out = div_inp_a;
                          end
                          1'b0: begin
                          out = ((is_neg(div_inp_a)) ^ (is_neg(div_inp_a))) ? negative(remainder) : remainder;   
                          end
                      endcase
                  end
              end
              
               divu: begin
                   if(divider_bypass_check) begin
                       out = quotient2; 
                   end
                   else begin
                       case (divide_by_zero)
                          1'b1: begin
                            out = 32'hffffffff;
                          end
                          1'b0: begin
                          out = quotient;  
                          end
                      endcase
                  end
              end
              
              remu: begin
                   if(divider_bypass_check) begin
                        out = remainder2;
                   end
                   else begin
                       case (divide_by_zero)
                          1'b1: begin
                            out = div_inp_a;
                          end
                          1'b0: begin
                          out = remainder;  
                          end
                      endcase
                  end
              end
              default: begin
                  out = 'x;
              end
           endcase 
        end
        else begin
            out = alu_out;
        end
    end
    
    always_comb begin
        quotient2 = '0;
        remainder2 = '0;
        
        if(div_inp_a == '0) begin
            quotient2 = '0;
            remainder2 = '0;
        end
        
        else if(div_inp_b > div_inp_a) begin
            quotient2 = '0;
            remainder2 = div_inp_a;
        end
        
        else if(div_inp_a == div_inp_b) begin
            quotient2 = 1;
            remainder2 = 0;
        end
        
        else if(div_inp_b == 1) begin
            quotient2 = div_inp_a;
            remainder2 = '0;
        end
        
        else if((div_inp_a == 1) && (div_inp_b != 1)) begin
                quotient2 = 0;
                remainder2 = 1;
        end
        
       // else if(power2(div_inp_b)) begin
       // quotient2 = div_inp_a >> $clog2(div_inp_b);
       // remainder2 = div_inp_a & (div_inp_b - 1);
       // end
    end
   
function logic is_neg(logic [31:0] data);
		return data[31];
endfunction

	function logic [31:0] negative(logic [31:0] data);
		return (~data) + 1;
	endfunction

function logic divider_bypass(logic [31:0] a, logic [31:0] b);
    if((a==b) || (a == 0) || ((a==1) || (b==1)) || (b > a)) begin
        return 1;
        end
     else return 0;
 endfunction
 
	
endmodule : execution_unit


module execution_stage
import rv32i_types::*;
#(parameter n_exec = EX_UNITS)
(
    input clk,
    input rst,
    input branch_mispredict,
    input rs_d rs_data[n_exec],
    output ex_data_bus_t data_bus[n_exec]
);

    logic [n_exec-1:0] mul_inst;
    logic [n_exec-1:0] done_inst;
    logic [n_exec-1:0] start_inst;
    generate for (genvar i = 0; i < n_exec; i++) begin : arrays
        execution_unit exec_array (
            .clk(clk),
            .rst(rst||branch_mispredict),
            .mult_inst_bit(mul_inst[i]),
            .done_inst(done_inst[i]),
            .start_inst(start_inst[i]),
            .rs_data(rs_data[i]),
            .data_bus(data_bus[i])
        );
    end endgenerate

endmodule : execution_stage