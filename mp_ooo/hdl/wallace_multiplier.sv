module wallace_multiplier
#(
    parameter int OPERAND_WIDTH = 32, parameter MULT_SETS = 11, parameter int TOTAL_MULTS = 33, parameter STAGES = 8
)
(
    input logic clk,
    input logic rst,
    // Start must be reset after the done flag is set before another multiplication can execute
    input logic start,

    // Use this input to select what type of multiplication you are performing
    // 0 = Multiply two unsigned numbers
    // 1 = Multiply two signed numbers
    // 2 = Multiply a signed number and unsigned number
    //      a = signed
    //      b = unsigned
    input logic [1:0] mul_type,

    input logic[OPERAND_WIDTH-1:0] a,
    input logic[OPERAND_WIDTH-1:0] b,
    output logic[2*OPERAND_WIDTH-1:0] p,
    output logic done
);

    // Constants for multiplication case readability
    `define UNSIGNED_UNSIGNED_MUL 2'b00
    `define SIGNED_SIGNED_MUL     2'b01
    `define SIGNED_UNSIGNED_MUL   2'b10

   // enum int unsigned {mult_idle, SHIFT, ADD, DONE} curr_state, next_state;
   
   typedef enum bit [1:0] {
        mult_idle  = 2'b00,
        partial_product = 2'b01,
        wallace_add  = 2'b10,
        sign_conversion = 2'b11
    } mult_controller_states;
    
    logic [1:0] state, next_state;
    localparam int OP_WIDTH_LOG = $clog2(OPERAND_WIDTH);
    logic [OPERAND_WIDTH - 1:0] counter;
    logic [OPERAND_WIDTH-1:0] a_reg, b_reg;
    // Number of stations to multiply
    logic [2*OPERAND_WIDTH-1:0] computation_stations[0:TOTAL_MULTS - 1];
    logic [2*OPERAND_WIDTH-1:0] final_sol, sol;
    logic [TOTAL_MULTS -1:0] early_finish_check;
    //
    logic [OP_WIDTH_LOG-1:0] mult_indices[0:MULT_SETS - 1];
    logic [OP_WIDTH_LOG-1:0] zero_indices[0:7];
    logic early_finish_true, extremely_early_check, neg_result;
    
    assign mult_indices = '{0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30};
    assign zero_indices = '{22, 16, 12, 8, 6, 4, 3, 2};
    assign extremely_early_check = ((a_reg == 0)|| (a_reg == 1) || (a_reg ==2) || (b_reg == 0) || (b_reg==1) || (b_reg ==2)) && (state == partial_product);
    assign sol = computation_stations[0] + computation_stations[1];
    
    always_comb begin
        next_state = state;
        p = '0;
        done = '0;
        unique case (state)
            mult_idle: begin
             if(start && ~rst) begin
             next_state = partial_product;
             end
             else next_state = mult_idle;
            end
            
            partial_product: begin
            if(extremely_early_check) next_state = sign_conversion;
            else next_state = wallace_add;
            end
            wallace_add: next_state =  rst ? mult_idle : early_finish_true || (counter == 32'h9) ? sign_conversion : wallace_add;
            sign_conversion: begin 
                 done = 1'b1;
                unique case (mul_type)
                    `UNSIGNED_UNSIGNED_MUL: p = final_sol[2*OPERAND_WIDTH-1:0];
                    `SIGNED_SIGNED_MUL,
                    `SIGNED_UNSIGNED_MUL: p = neg_result ? (~final_sol[2*OPERAND_WIDTH-1-1:0])+1'b1 : final_sol;
                    default: ;
                endcase
                next_state = mult_idle;
            end
            default: ;
        endcase
    end
    
    always_comb begin
        for(int i=0; i<2; i++) begin
           early_finish_check[i] = '0; 
        end
        
        for(int i=2; i < TOTAL_MULTS; i++) begin
        early_finish_check[i] = |computation_stations[i];
        end
      early_finish_true = (~|early_finish_check) && (counter != '0);    
    end
    
    always_comb begin
    final_sol = sol;
    if((a_reg == 0) || (b_reg == 0)) final_sol = '0;
    if((a_reg == 1) || (a_reg == 2)) final_sol = {32'b0, b_reg} << {32'b0, (a_reg - 1)};
    if((b_reg == 1) || (b_reg == 2)) final_sol = {32'b0, a_reg} << {32'b0, (b_reg - 1)};
    end
    
    always_ff @(posedge clk) begin
        if(rst || done) begin
            state <= mult_idle;
            counter <= 'x;
            for(int i =0; i < TOTAL_MULTS; i++) begin
                computation_stations[i] <= 'x;
            end
        end
        
        else begin
            state <= next_state;
            unique case(state)
                mult_idle: begin
                    if(start && ~rst) begin
                    counter <= '0;
                    for(int i = 0; i < TOTAL_MULTS; i++) begin
			    computation_stations[i] <= '0;
		    end
              unique case (mul_type)
                            `UNSIGNED_UNSIGNED_MUL:
                            begin
                                neg_result <= '0;   // Not used in case of unsigned mul, but just cuz . . .
                                a_reg <= a;
                                b_reg <= b;
                            end
                            `SIGNED_SIGNED_MUL:
                            begin
                                // A -*+ or +*- results in a negative number unless the "positive" number is 0
                                neg_result <= (a[OPERAND_WIDTH-1] ^ b[OPERAND_WIDTH-1]) && ((a != '0) && (b != '0));
                                // If operands negative, make positive
                                a_reg <= (a[OPERAND_WIDTH-1]) ?  {(~a + 1'b1)} : a;
                                b_reg <= (b[OPERAND_WIDTH-1]) ? {(~b + 1'b1)} : b;
                            end
                            `SIGNED_UNSIGNED_MUL:
                            begin
                                neg_result <= a[OPERAND_WIDTH-1];
                                a_reg <= (a[OPERAND_WIDTH-1]) ? {(~a + 1'b1)} : a;
                                b_reg <= b;
                            end
                            default:;
                        endcase
                        
                    end
                end
                
                partial_product: begin
                
                 for (int i = 0; i < 32; i++) begin 
			unique case (b_reg[i])
				1'b1: computation_stations[i] <= ({32'b0, a_reg} << i);
				1'b0: ;
				default:;
			endcase
		end                    
                end
                
                wallace_add: begin
                 for (int i = 0; i < MULT_SETS; i++) begin 
			         computation_stations[mult_indices[i] + 0 - unsigned'(i)]	<= computation_stations[mult_indices[i] + 0] ^ computation_stations[mult_indices[i] + 1] ^ computation_stations[mult_indices[i] + 2];
			          computation_stations[mult_indices[i] + 1 - unsigned'(i)]	<= ((computation_stations[mult_indices[i] + 0] & computation_stations[mult_indices[i] + 1]) | 
												(computation_stations[mult_indices[i] + 1] & computation_stations[mult_indices[i] + 2]) | 
												(computation_stations[mult_indices[i] + 0] & computation_stations[mult_indices[i] + 2])) << 1;
		         end 
		         for (int i = 0; i < TOTAL_MULTS; i++) begin 
			         computation_stations[zero_indices[counter] + unsigned'(i)] <= '0;
               if((zero_indices[counter] + unsigned'(i)) == unsigned'(TOTAL_MULTS - 1)) break;
		         end
		
		          counter <= counter + 1;
                end
                
                default: ;
            endcase
        end
    end
   

   

endmodule
