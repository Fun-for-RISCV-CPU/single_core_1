
module new_divider
import rv32i_types::*;
(
	input logic inst_clk,
	input logic rst,
	input logic inst_start,
	input logic [31:0] inst_a,
	input logic [31:0] inst_b,
	output logic [31:0] quotient_inst,
	output logic [31:0] remainder_inst,
	output logic complete_inst,
	output logic divide_by_0
);

	enum bit [1:0] {
		div_idle			= 2'b00,
		shift_sub		 = 2'b01,
		done			 = 2'b10
	} state, next_state;

	logic [31:0] local_numerator, local_denominator;
	logic [31:0] Q;
	logic [31:0] R;
	logic [31:0] R_SUB;

	
	logic [31:0] counter;


//State transitions
assign divide_by_0 = (inst_b == '0);
assign quotient_inst = Q;
assign remainder_inst = R;
assign R_SUB = R - inst_b;
always_comb begin
next_state = state;
complete_inst = 1'b0;
 case (state)
    div_idle: begin
        if(inst_start && !divide_by_0) next_state = shift_sub;
        else next_state = div_idle;
        if(inst_start && divide_by_0) complete_inst = 1'b1;
    end
    
    shift_sub: begin
            if(counter == '0) next_state = done;
            else next_state = shift_sub;
    end
    
    done: begin
    next_state = div_idle;
    complete_inst = 1'b1;
    end

endcase
end

always_ff @(posedge inst_clk) begin
    if(rst) begin
        counter <= '0;
        Q <= '0;
        R <= '0;
        state <= div_idle;
end
    else begin
    state <= next_state;
    
    case (state)
    
        div_idle: begin
            if(inst_start) begin
                Q <= '0;
                R <= '0;
                counter <= log2(inst_a);
            end   
            end
         shift_sub: begin
            if (inst_b <= R) begin
							Q[31:0] <= {Q[30:0], 1'b1};
							if (counter != '0)
								R[31:0] <= {R_SUB[30:0], inst_a[counter - 1'b1]};
							else
								R[31:0] <= R_SUB;
					end else begin
							Q <= {Q[30:0], 1'b0};
							if (counter != '0)
								R[31:0] <= {R[30:0], inst_a[counter - 1'b1]};
							else
								R[31:0] <= R[31:0];
					end

					counter <= counter - 1'b1;
         end
         
         done: begin
            Q <= '0;
            R <= '0;
            counter <= '0;
         end
    endcase
        
    end
end


function logic [31:0] log2(logic [31:0] data);
      log2 = '0;
      for (int i = 0; i < 31; i = i + 1) begin
        if (data[31 - i] == 1'b1)begin
            log2 = 32 - unsigned'(i);
            break;
        end  
        end
       return log2;
	endfunction



endmodule