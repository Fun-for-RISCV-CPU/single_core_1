module load_store
import rv32i_types::*;
#(parameter ls_q_depth = 16, parameter rob_data_bus_size = 32, rob_size = 5)
(
    input logic clk,
    input logic rst,
    input ls_q_entry ls_q_inst1,
    //input logic[rob_size-1:0] rob_id_dest,
    input rob_entry_t [rob_data_bus_size-1:0] rob_data_bus,
    input logic in_flight_mem,
    //input logic mem_data_ready,
    output logic full, empty,
    output ls_q_entry ls_q_o
);

logic   [1:0] action;
ls_q_entry load_store_queue[ls_q_depth];
int front, rear;
assign full = (front == ((rear+1) % ls_q_depth));
assign empty = (front == -1);

//assign push = empty && inst1.valid && inst1.mem_inst || inst1.valid && inst1.mem_inst && in_flight_mem || ~full && (~load_store_queue[front].r1 || ~load_store_queue[front].r2) ;
//assign pop = (~empty && inst1.valid && ~inst1.mem_inst && ~in_flight_mem && load_store_queue[front].r1 && load_store_queue[front].r2) || full && ~in_flight_mem && load_store_queue[front].r1 && load_store_queue[front].r2;
//assign push_pop = ~empty && inst1.valid && inst1.mem_inst && ~in_flight_mem && load_store_queue[front].r1 && load_store_queue[front].r2;
//assign none = (full && in_flight_mem) || ~inst1.valid && (~load_store_queue[front].r1 || ~load_store_queue[front].r2) || empty && inst1.valid && ~inst1.mem_inst;

always_comb begin
action = none;
if(empty && ls_q_inst1.valid && ls_q_inst1.mem_inst || ~full && ls_q_inst1.valid && ls_q_inst1.mem_inst && in_flight_mem || ~full && ls_q_inst1.valid && ls_q_inst1.mem_inst && ~load_store_queue[front].r1) action = push;
else if((~empty && ~ls_q_inst1.mem_inst && ~in_flight_mem && load_store_queue[front].r1) || full && ~in_flight_mem && load_store_queue[front].r1)action = pop;
else if(~empty && ls_q_inst1.valid && ls_q_inst1.mem_inst && ~in_flight_mem && load_store_queue[front].r1)action = push_pop;
else if((full && in_flight_mem) || ~ls_q_inst1.valid && ~load_store_queue[front].r1 || empty && ls_q_inst1.valid && ~ls_q_inst1.mem_inst)action = none;
end

always_comb begin
ls_q_o = 'x;
if(action == pop || action == push_pop) ls_q_o = load_store_queue[front];
else begin
  ls_q_o.valid = 1'b0;
  ls_q_o.mem_inst = 1'b0;
end
end

always_ff @(posedge clk) begin
    

    if(rst) begin
        front <= -1;
        rear <= -1;
        for(int i=0; i< ls_q_depth; i++) begin
            load_store_queue[i].valid <= 1'b0;
            load_store_queue[i].rob_id <= 'x;
            load_store_queue[i].rob_id2 <= 'x;
            load_store_queue[i].rob_id_dest <= 'x;
            load_store_queue[i].funct3 <= 'x;
            load_store_queue[i].rs1_v <= 'x;
            load_store_queue[i].rs2_v <= 'x;
            load_store_queue[i].r1 <= 1'b0;
            load_store_queue[i].r2 <= 1'b0;
            load_store_queue[i].ls_imm <= 'x;
        end
    end

    else begin
        if(action == none) begin
            front <= front;
            rear <= rear;
        end
        else if(action == push) begin
            rear <= (rear + 1) % ls_q_depth;
            if(front == -1) front <= 0;
            else front <= front;
            for(int i=0; i< ls_q_depth; i++) begin
                if(i == ((rear + 1) % ls_q_depth) )
                begin
                    load_store_queue[(rear + 1) % ls_q_depth] <= ls_q_inst1;
                    //load_store_queue[(rear + 1) % ls_q_depth].rob_id_dest <= rob_id_dest;
                end
            end
        end

        else if(action == 2'b10)begin
           // ls_q_o <= load_store_queue[front];
            load_store_queue[front].valid <= 1'b0;
            if(front == rear) begin
                front <= -1;
                rear <= -1;
            end
            else front <= (front + 1) % ls_q_depth;
        end

        else if(action == 2'b11) begin
            front <= (front + 1) % ls_q_depth;
            rear <= (rear + 1) % ls_q_depth;
           // ls_q_o <= load_store_queue[front];
            for(int i=0; i< ls_q_depth; i++) begin
                if(i == ((rear + 1) % ls_q_depth) )
                begin
                    load_store_queue[(rear + 1) %ls_q_depth] <= ls_q_inst1;
                    //load_store_queue[(rear + 1) % ls_q_depth].rob_id_dest <= rob_id_dest;
                end
            end
        end

        for(int i=0; i < ls_q_depth; i++) begin
            if((load_store_queue[i].r1 == 1'b0) && (rob_data_bus[load_store_queue[i].rob_id].ready) && load_store_queue[i].valid) begin
                load_store_queue[i].rs1_v <= rob_data_bus[load_store_queue[i].rob_id].rd_data;
                load_store_queue[i].r1 <= 1'b1;
            end
            
             if((load_store_queue[i].r2 == 1'b0) && (rob_data_bus[load_store_queue[i].rob_id2].ready) && load_store_queue[i].valid) begin
                load_store_queue[i].rs2_v <= rob_data_bus[load_store_queue[i].rob_id2].rd_data;
                load_store_queue[i].r2 <= 1'b1;
            end
        end
         
    end
end


endmodule : load_store
