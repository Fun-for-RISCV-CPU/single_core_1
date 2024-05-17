module instruction_q #(parameter width = 65, parameter depth = 32)
(
    input logic clk,
    input logic rst,
    input logic branch_mispredict,
    input logic [width-1:0] inst_in,
    input logic [1:0] action,
    output logic [width-1:0] inst_out,
    output logic empty,
    output logic full
);

// action: 00 means neither load anything to the queue nor get something out of the queue
// 01 means just load to the queue (reservations station or rob is full) - instructions are loaded one cycle after the input is set
// and 11 means means load as wel get out (normal operation) - you start getting instructions out 2 cycles after you load them
//10 means that you can get stuff out from the queue but not load in (delays from icache)
//01 high for 1 cycle, saves the data in the register (to begin with)
//after that you can store data in the que and get something out of it every cycle if there are no delays

logic [depth-1:0][width-1:0] instruction_arr;
int front, rear;


//assign full = ((total_element) == depth);
//assign empty = (total_element == 0);

assign full = (front == ((rear+1) % depth));
assign empty = (front == -1);

// always_comb begin
//     if (action == 2'b10 || action == 2'b11) begin
//         inst_out = instruction_arr[front];
//     end 
//     else begin
//         inst_out[63:0] = 'x;
//         inst_out[64] = 1'b0;
//     end
// end

always_ff @(posedge clk) begin
    inst_out[63:0] <= 'x;
    inst_out[64] <= 1'b0;
    // Reset queue on branch or jump
    if(rst || branch_mispredict) begin
        front <= -1;
        rear <= -1;
        for(int i=0; i< depth; i++) begin
            instruction_arr[i] <= 'x;
        end
    end
    else begin
        if(action == 2'b00) begin
            front <= front;
            rear <= rear;
            for(int i=0; i< depth; i++) begin
                instruction_arr[i] <= instruction_arr[i];
            end
        end

        else if(action == 2'b01) begin
            rear <= (rear + 1) % depth;
            if(front == -1) front <= 0;
            else front <= front;
            for(int i=0; i< depth; i++) begin
                if(i == ((rear + 1) % depth) )
                begin
                    instruction_arr[(rear + 1) % depth] <= inst_in;
                end
                else begin
                    instruction_arr[i] <= instruction_arr[i];
                end
            end
        end

        else if(action == 2'b10)begin
            inst_out <= instruction_arr[front];
            if(front == rear) begin
                front <= -1;
                rear <= -1;
            end
            else front <= (front + 1) % depth;
            for(int i=0; i< depth; i++) begin
                instruction_arr[i] <= instruction_arr[i];
            end
        end

        else if(action == 2'b11) begin
            front <= (front + 1) % depth;
            rear <= (rear + 1) % depth;
            inst_out <= instruction_arr[front];
            for(int i=0; i< depth; i++) begin
                if(i == ((rear + 1) % depth) )
                begin
                    instruction_arr[(rear + 1) % depth] <= inst_in;
                end
                else begin
                    instruction_arr[i] <= instruction_arr[i];
                end
            end
        end

        end  
    end

endmodule : instruction_q
