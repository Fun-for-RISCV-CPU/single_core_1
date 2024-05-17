module store_buffer
import rv32i_types::*;
#(parameter store_buffer_depth = 4)
(
    input logic clk,
    input logic rst,
    input ls_mem_bus_t mem_input,
    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    output  logic   [31:0]  dmem_wdata,
    input logic[1:0] mem_state,
    output logic store_buffer_full, store_buffer_empty
);


int front_store_buffer, rear_store_buffer;
logic [1:0] action_store_buffer;
assign store_buffer_full = (front_store_buffer == ((rear_store_buffer+2) % store_buffer_depth) || front_store_buffer == ((rear_store_buffer+1) % store_buffer_depth));
assign store_buffer_empty = (front_store_buffer == -1);

store_buffer_entry store_buffer[store_buffer_depth];

//enqueuing dequeuing logic in load store buffer
always_comb begin
    action_store_buffer = none;
    if( store_buffer_empty && mem_input.valid && (mem_input.dmem_rmask == 4'b0000)|| 
    mem_input.valid && (mem_input.dmem_rmask == 4'b0000) && (mem_state != mem_idle)) begin
            action_store_buffer = push;
        end
         else if(~store_buffer_empty && (~mem_input.valid || (mem_input.dmem_wmask == 4'b0000)) && (mem_state == mem_idle)) begin
                
                action_store_buffer = pop;
        end
        else if(~store_buffer_empty && mem_input.valid && (mem_input.dmem_rmask == 4'b0000) && (mem_state == mem_idle)) begin
                action_store_buffer = push;
        end

end


// Combinational dequeing of store buffer
always_comb begin
dmem_addr = 'x;
dmem_wdata = 'x;
dmem_rmask = '0;
dmem_wmask = '0;
if(action_store_buffer == pop || action_store_buffer == push_pop) begin
    dmem_addr = store_buffer[front_store_buffer].dmem_addr;
    dmem_wdata = {store_buffer[front_store_buffer].dmem_wdata[31:2], 2'b00};
    dmem_wmask = store_buffer[front_store_buffer].dmem_wmask;
end
end

always_ff @(posedge clk) begin
if(rst) begin
for(int i = 0; i < store_buffer_depth; i++) begin
    store_buffer[i].dmem_wdata <= 'x;
    store_buffer[i].dmem_addr <= 'x;
    store_buffer[i].dmem_wmask <= '0;
end
end
else begin
  if(action_store_buffer == push) begin
             rear_store_buffer <= (rear_store_buffer + 1) % store_buffer_depth;
            if(front_store_buffer == -1) front_store_buffer <= 0;
            else front_store_buffer <= front_store_buffer;
            for(int i=0; i< store_buffer_depth; i++) begin
                if(i == ((rear_store_buffer + 1) % store_buffer_depth) )
                begin
                    store_buffer[(rear_store_buffer + 1) % store_buffer_depth].dmem_wdata <= mem_input.dmem_wdata;
                    store_buffer[(rear_store_buffer + 1) % store_buffer_depth].dmem_addr <= mem_input.dmem_addr;
                    store_buffer[(rear_store_buffer + 1) % store_buffer_depth].dmem_wmask <= mem_input.dmem_wmask;
                end
            end
        end
        
   else if(action_store_buffer == pop)begin
           // ls_q_o <= load_store_queue[front];
            if(front_store_buffer == rear_store_buffer) begin
                front_store_buffer <= -1;
                rear_store_buffer <= -1;
            end
            else front_store_buffer <= (front_store_buffer + 1) % store_buffer_depth;
        end
        
    else if(action_store_buffer == push_pop) begin
            front_store_buffer <= (front_store_buffer + 1) % store_buffer_depth;
            rear_store_buffer <= (rear_store_buffer + 1) % store_buffer_depth;
           // ls_q_o <= load_store_queue[front];
            for(int i=0; i< store_buffer_depth; i++) begin
                if(i == ((rear_store_buffer + 1) % store_buffer_depth) )
                begin
                    store_buffer[(rear_store_buffer + 1) % store_buffer_depth].dmem_wdata <= mem_input.dmem_wdata;
                    store_buffer[(rear_store_buffer + 1) % store_buffer_depth].dmem_addr <= mem_input.dmem_addr;
                    store_buffer[(rear_store_buffer + 1) % store_buffer_depth].dmem_wmask <= mem_input.dmem_wmask;
                end
            end
        end

end
end


endmodule: store_buffer