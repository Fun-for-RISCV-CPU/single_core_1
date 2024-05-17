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
    
    always_comb begin
         // The instruction is multiply
        mult_inst = (rs_data.opcode == op_b_reg) && (rs_data.funct7 == 7'b0000001);
        if (mult_inst) begin   
            ready = done && rs_data.r1 && rs_data.r2;
            start = rs_data.r1 && rs_data.r2 || done;
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
        else begin
            out = alu_out;
        end
    end

endmodule : execution_unit


module execution_stage
import rv32i_types::*;
#(parameter n_exec = 8)
(
    input clk,
    input rst,
    input rs_d rs_data[n_exec],
    output ex_data_bus_t data_bus[n_exec]
);

    logic [n_exec-1:0] mul_inst;
    generate for (genvar i = 0; i < n_exec; i++) begin : arrays
        execution_unit exec_array (
            .clk(clk),
            .rst(rst),
            .mult_inst_bit(mul_inst[i]),
            .rs_data(rs_data[i]),
            .data_bus(data_bus[i])
        );
    end endgenerate

endmodule : execution_stage