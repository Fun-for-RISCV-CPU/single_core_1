module load_store
import rv32i_types::*;
#(parameter l_q_depth = 8, s_q_depth = 8,  ld_res_station = 1, str_res_station = 1, rob_size = ROB_ID_SIZE)
(
    input logic clk,
    input logic rst,
    input   logic               branch_mispredict,
    input ls_q_entry ls_q_inst1,
    //input logic[rob_size-1:0] rob_id_dest,
    input rob_entry_t [2**rob_size-1:0] rob_data_bus,
    input [rob_size - 1:0] rob_tail_ptr,
    //input logic mem_data_ready,
    output logic full_load, empty_load, full_store, empty_store,
    output ls_rob_data_bus_t load_rob_data_bus, store_rob_data_bus,
    output ls_mem_bus_t mem_input,
    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    output  logic   [31:0]  dmem_wdata,
    input logic[1:0] mem_state
);

logic [31:0] dmem_store_addr, dmem_load_addr, dmem_store_wdata;
logic   [1:0] action_load, action_store;
logic [3:0] dmem_store_wmask;
logic [s_q_depth - 1:0][31:0]       address_array;
logic  load_sent_to_mem, store_sent_to_mem;
ls_q_entry load_queue[l_q_depth], lo1, so1;
ls_q_entry store_queue[s_q_depth];
load_res_station_entry load_res_station[ld_res_station];
store_res_station_entry store_res_station[str_res_station];
int front_load, rear_load, front_store, rear_store;
assign full_load = (front_load == ((rear_load+1) % l_q_depth));
assign empty_load = (front_load == -1);
assign full_store = (front_store == ((rear_store+1) % s_q_depth));
assign empty_store = (front_store == -1);

generate for (genvar i = 0; i < s_q_depth; i++) begin
    adder adder(
        .a(store_queue[i].rs1_v),
        .b(store_queue[i].ls_imm),
        .out(address_array[i])
    );


end endgenerate


always_comb begin
    
    dmem_load_addr = 'x;
    dmem_store_addr = 'x;
    dmem_wmask = '0;
     dmem_rmask = '0;
     dmem_wdata = 'x;
     dmem_addr = 'x;
    
    
     load_rob_data_bus.ready = 1'b0;
    load_rob_data_bus.valid = 1'b0;
    load_rob_data_bus.rob_id = 'x;
    load_rob_data_bus.rd_data = 'x;
    load_rob_data_bus.dmem_rmask = '0;
    load_rob_data_bus.dmem_wmask = '0;
    load_rob_data_bus.dmem_wdata = 'x;
    load_rob_data_bus.dmem_addr = 'x;
    load_rob_data_bus.dmem_rdata = 'x;
    load_rob_data_bus.rs1_v = 'x;
    load_rob_data_bus.rs2_v = 'x;

    store_rob_data_bus.ready = 1'b0;
    store_rob_data_bus.valid = 1'b0;
    store_rob_data_bus.rob_id = 'x;
    store_rob_data_bus.rd_data = 'x;
    store_rob_data_bus.dmem_rmask = '0;
    store_rob_data_bus.dmem_wmask = '0;
    store_rob_data_bus.dmem_wdata = 'x;
    store_rob_data_bus.dmem_addr = 'x;
    store_rob_data_bus.dmem_rdata = 'x;
    store_rob_data_bus.rs1_v = 'x;
    store_rob_data_bus.rs2_v = 'x;

    if(load_res_station[0].valid) begin
        load_rob_data_bus.ready = 1'b0;
        load_rob_data_bus.valid = 1'b1;
        load_rob_data_bus.rob_id = load_res_station[0].rob_id_dest;
        load_rob_data_bus.rd_data = 'x;
        load_rob_data_bus.dmem_rmask = load_res_station[0].dmem_rmask;
        load_rob_data_bus.dmem_wmask = '0;
        load_rob_data_bus.dmem_wdata = 'x;
        load_rob_data_bus.dmem_addr = load_res_station[0].dmem_addr;
        load_rob_data_bus.dmem_rdata = 'x;
        load_rob_data_bus.rs1_v = load_res_station[0].rs1_v;
        load_rob_data_bus.rs2_v = 'x;
    end

    if(store_res_station[0].valid) begin
        store_rob_data_bus.ready = 1'b0;
        store_rob_data_bus.valid = 1'b1;
        store_rob_data_bus.rob_id = store_res_station[0].rob_id_dest;
        store_rob_data_bus.rd_data = 'x;
        store_rob_data_bus.dmem_rmask = '0;
        store_rob_data_bus.dmem_wdata = store_res_station[0].dmem_wdata;
        store_rob_data_bus.dmem_wmask = store_res_station[0].dmem_wmask;
        store_rob_data_bus.dmem_addr = store_res_station[0].dmem_addr;
        store_rob_data_bus.dmem_rdata = 'x;
        store_rob_data_bus.rs1_v = store_res_station[0].rs1_v;
        store_rob_data_bus.rs2_v = store_res_station[0].rs2_v;
    end
    
    if(lo1.valid) dmem_load_addr = lo1.rs1_v + lo1.ls_imm;
    if(so1.valid) dmem_store_addr = so1.rs1_v + so1.ls_imm;
    // Setting rob bus to be ready to get data from load_store queue

// Preparing data to be sent to mem controller
    mem_input = '0;
    load_sent_to_mem = 1'b0;
    store_sent_to_mem = 1'b0;

    if(store_res_station[0].valid 
    && (store_res_station[0].rob_id_dest == rob_tail_ptr)
    && (mem_state == mem_idle)) begin
        mem_input.dmem_wmask = store_res_station[0].dmem_wmask;
        dmem_wmask = store_res_station[0].dmem_wmask;
        mem_input.dmem_wdata = store_res_station[0].dmem_wdata;
        dmem_wdata = store_res_station[0].dmem_wdata;
        mem_input.dmem_addr = store_res_station[0].dmem_addr;
        dmem_addr = {store_res_station[0].dmem_addr[31:2], 2'b00};
        mem_input.dmem_rmask = '0;
        dmem_rmask = '0;
        mem_input.valid = 1'b1;
        store_sent_to_mem = 1'b1;
        mem_input.rob_id = store_res_station[0].rob_id_dest;
         mem_input.funct3 = 'x;
    end
    else if(load_res_station[0].valid 
    && (load_res_station[0].ready_for_mem)
    && (mem_state == mem_idle)) begin
        mem_input.dmem_wmask = '0;
         dmem_wmask = '0;
        mem_input.dmem_wdata = 'x;
        dmem_wdata = 'x;
        mem_input.dmem_addr =  {load_res_station[0].dmem_addr};
        dmem_addr = {load_res_station[0].dmem_addr[31:2], 2'b00};
        mem_input.dmem_rmask = load_res_station[0].dmem_rmask;
        dmem_rmask = load_res_station[0].dmem_rmask;
        mem_input.rob_id = load_res_station[0].rob_id_dest;
        load_sent_to_mem = 1'b1;
         mem_input.valid = 1'b1;
         mem_input.funct3 = load_res_station[0].funct3;
    end

end

// Filling load and store reservation stations with dequed data 
always_ff @(posedge clk) begin
    if(rst || branch_mispredict || load_sent_to_mem) begin
        for(int i=0;i < ld_res_station; i++) begin
            load_res_station[i].valid <= 1'b0;
            load_res_station[i].dmem_addr <= 'x;
            load_res_station[i].age <= 'x;
            load_res_station[i].rob_id_dest <= 'x;
            load_res_station[i].dmem_rdata <= 'x;
            load_res_station[i].rd_data <= 'x;
            load_res_station[i].dmem_rmask <= '0;
            load_res_station[i].funct3 <= 'x; 
            load_res_station[i].rs1_v <= 'x;
            load_res_station[i].ready_for_mem <= 1'b0;
        end
    end

    else begin
        
        if(lo1.valid) begin
            load_res_station[0].valid <= lo1.valid;
            load_res_station[0].dmem_addr <= lo1.rs1_v + lo1.ls_imm;
            load_res_station[0].age <= lo1.age;
            load_res_station[0].rob_id_dest <= lo1.rob_id_dest;
            load_res_station[0].dmem_rdata <= 'x;
            load_res_station[0].rd_data <= 'x;
            load_res_station[0].funct3 <= lo1.funct3;
            load_res_station[0].rs1_v <= lo1.rs1_v;
            load_res_station[0].ready_for_mem <= lo1.ready_for_mem; 
            unique case (lo1.funct3)
            lb, lbu: load_res_station[0].dmem_rmask <= 4'b0001 << dmem_load_addr[1:0];
            lh, lhu: load_res_station[0].dmem_rmask <= 4'b0011 << dmem_load_addr[1:0];
            lw:      load_res_station[0].dmem_rmask <= 4'b1111;
            default: load_res_station[0].dmem_rmask <= 'x;
        endcase
        end
        
        else begin
            //logic to send load to mem
        if(store_res_station[0].valid && (store_res_station[0].age > load_res_station[0].age)) begin
            load_res_station[0].ready_for_mem <= 1'b1;
        end
        
        else if(store_res_station[0].valid && (store_res_station[0].age < load_res_station[0].age) && (store_res_station[0].dmem_addr == load_res_station[0].dmem_addr)) begin
              load_res_station[0].ready_for_mem <= 1'b0;     
        end
        
        else begin
            if(empty_store) begin
                load_res_station[0].ready_for_mem <= 1'b1;
            end
            
            else begin
                for(int i=0; i < s_q_depth; i++) begin
                    if(((front_store + i) % s_q_depth) == rear_store) begin
                        if(store_queue[rear_store].address_computed) begin
                            if(store_queue[rear_store].valid && ((store_queue[rear_store].age > load_res_station[0].age) 
                            || ((store_queue[rear_store].age < load_res_station[0].age) && (store_queue[rear_store].dmem_addr != load_res_station[0].dmem_addr)))) begin
                                  load_res_station[0].ready_for_mem <= 1'b1;
                                  break;
                            end
                            else if(!store_queue[rear_store].valid) begin
                                  load_res_station[0].ready_for_mem <= 1'b1;
                                  break;
                            end
                            else begin
                                  load_res_station[0].ready_for_mem <= 1'b0;
                                  break;
                            end
                        end
                        else begin
                             if(store_queue[rear_store].valid) begin
                                load_res_station[0].ready_for_mem <= 1'b0;
                                break;
                            end
                            else begin
                                load_res_station[0].ready_for_mem <= 1'b1;
                                break; 
                            end
                        end
                    end
                    else begin
                          if(store_queue[(front_store + i) % s_q_depth].address_computed) begin 
                              if(store_queue[(front_store + i) % s_q_depth].valid && (store_queue[(front_store + i) % s_q_depth].age > load_res_station[0].age)) begin
                                  load_res_station[0].ready_for_mem <= 1'b1;
                                  break;
                              end
                              
                              else if(store_queue[(front_store + i) % s_q_depth].valid && (store_queue[(front_store + i) % s_q_depth].age < load_res_station[0].age) 
                              && (store_queue[(front_store + i) % s_q_depth].dmem_addr == load_res_station[0].dmem_addr) ) begin
                                    load_res_station[0].ready_for_mem <= 1'b0;
                                    break;
                              end
                          end
                          else begin
                                  if(store_queue[(front_store + i) % s_q_depth].valid && (store_queue[(front_store + i) % s_q_depth].age > load_res_station[0].age)) begin
                                  load_res_station[0].ready_for_mem <= 1'b1;
                                  break;
                              end
                              
                              else begin
                                  load_res_station[0].ready_for_mem <= 1'b0;
                                  break;
                              end
                          end
                    end
                end
            end
        end
        end

    end


    // Add similar for store res station

    if(rst || branch_mispredict || store_sent_to_mem) begin
        for(int i=0;i < ld_res_station; i++) begin
           store_res_station[i].valid <= 1'b0;
           store_res_station[i].dmem_addr <= 'x;
           store_res_station[i].age <= 'x;
           store_res_station[i].rob_id_dest <= 'x;
           store_res_station[i].dmem_wdata <= 'x;
           store_res_station[i].funct3 <= 'x; 
           store_res_station[i].rs1_v <= 'x; 
           store_res_station[i].rs2_v <= 'x;
           store_res_station[i].dmem_wmask <= 'x;
        end
    end

    else begin
        if(so1.valid) begin
            unique case (so1.funct3)
            sb: store_res_station[0].dmem_wmask <= 4'b0001 <<  dmem_store_addr[1:0];
            sh: store_res_station[0].dmem_wmask <= 4'b0011 <<  dmem_store_addr[1:0];
            sw: store_res_station[0].dmem_wmask <= 4'b1111;
            default: store_res_station[0].dmem_wmask <= 'x;
            endcase
            unique case (so1.funct3)
            sb:  store_res_station[0].dmem_wdata[8 * dmem_store_addr[1:0] +: 8 ] <= so1.rs2_v[7 :0];
            sh: store_res_station[0].dmem_wdata[16* dmem_store_addr[1]   +: 16] <= so1.rs2_v[15:0];
            sw: store_res_station[0].dmem_wdata <= so1.rs2_v;
            default: store_res_station[0].dmem_wdata <= 'x;
            endcase

           store_res_station[0].valid <= so1.valid;
           store_res_station[0].dmem_addr <= so1.rs1_v + so1.ls_imm;
           store_res_station[0].age <= so1.age;
           store_res_station[0].rob_id_dest <= so1.rob_id_dest;
           store_res_station[0].funct3 <= so1.funct3;
           store_res_station[0].rs1_v <=  so1.rs1_v;
           store_res_station[0].rs2_v <= so1.rs2_v;
        end
    end

end
// Enqueue and dequue logic for load store queue   
always_comb begin
    //verify logic
    action_load = none;
    action_store = none;
    if(empty_load && ls_q_inst1.valid && ls_q_inst1.mem_inst && ls_q_inst1.l_s || 
    ~full_load && ls_q_inst1.valid && ls_q_inst1.mem_inst && load_res_station[0].valid && ls_q_inst1.l_s  || 
    ~full_load && ls_q_inst1.valid && ls_q_inst1.mem_inst && ((~load_queue[front_load].r1 || ~load_queue[front_load].r2) && ls_q_inst1.l_s)) begin
    
            action_load = push;
        end
        else if((~empty_load && (~ls_q_inst1.mem_inst || ~ls_q_inst1.l_s) && ~load_res_station[0].valid && load_queue[front_load].r1 && load_queue[front_load].r2) || 
                full_load && ~load_res_station[0].valid && load_queue[front_load].r1 && load_queue[front_load].r2) begin
                
                action_load = pop;
        end
        else if(~empty_load && ls_q_inst1.valid && ls_q_inst1.mem_inst && ls_q_inst1.l_s && ~load_res_station[0].valid && load_queue[front_load].r1 && load_queue[front_load].r2) begin
                action_load = push_pop;
        end


if(empty_store && ls_q_inst1.valid && ls_q_inst1.mem_inst && ~ls_q_inst1.l_s || 
    ~full_store && ls_q_inst1.valid && ls_q_inst1.mem_inst && store_res_station[0].valid && ~ls_q_inst1.l_s  || 
    ~full_store && ls_q_inst1.valid && ls_q_inst1.mem_inst && ((~store_queue[front_store].r1 || ~store_queue[front_store].r2) && ~ls_q_inst1.l_s)) begin
    
            action_store = push;
        end
        else if((~empty_store && (~ls_q_inst1.mem_inst || ls_q_inst1.l_s) && ~store_res_station[0].valid && store_queue[front_store].r1 && store_queue[front_store].r2) || 
                full_store && ~store_res_station[0].valid && store_queue[front_store].r1 && store_queue[front_store].r2) begin
                
                action_store = pop;
        end
        else if(~empty_store && ls_q_inst1.valid && ls_q_inst1.mem_inst && ~ls_q_inst1.l_s && ~store_res_station[0].valid && store_queue[front_store].r1 && store_queue[front_store].r2) begin
                action_store = push_pop;
        end


end

// combinational assignments of the dequeued load queue and store queue data
always_comb begin
lo1 = 'x;
so1 = 'x;
if(action_load == pop || action_load == push_pop) lo1 = load_queue[front_load];
else begin
  lo1.valid = 1'b0;
  lo1.mem_inst = 1'b0;
end
if(action_store == pop || action_store == push_pop) so1 = store_queue[front_store];
else begin
  so1.valid = 1'b0;
  so1.mem_inst = 1'b0;
end
end

//Updataing front and rear pointers
always_ff @(posedge clk) begin 
    if(rst || branch_mispredict) begin
        front_load <= -1;
        rear_load <= -1;
        front_store <= -1;
        rear_store <= -1;
        for(int i=0; i< l_q_depth; i++) begin
            load_queue[i].valid <= 1'b0;
            load_queue[i].rob_id <= 'x;
            load_queue[i].rob_id2 <= 'x;
            load_queue[i].rob_id_dest <= 'x;
            load_queue[i].funct3 <= 'x;
            load_queue[i].rs1_v <= 'x;
            load_queue[i].rs2_v <= 'x;
            load_queue[i].r1 <= 1'b0;
            load_queue[i].r2 <= 1'b0;
            load_queue[i].ls_imm <= 'x;
            load_queue[i].age <= 'x;
            load_queue[i].speculation_bit <= 'x;
            load_queue[i].issued <= 1'b0;
            load_queue[i].address_computed <= 1'b0;
            load_queue[i].dmem_addr <= 'x;
            load_queue[i].ready_for_mem <= 1'b0;
            
            
        end

        for(int i=0; i< s_q_depth; i++) begin
            store_queue[i].valid <= 1'b0;
            store_queue[i].rob_id <= 'x;
            store_queue[i].rob_id2 <= 'x;
            store_queue[i].rob_id_dest <= 'x;
            store_queue[i].funct3 <= 'x;
            store_queue[i].rs1_v <= 'x;
            store_queue[i].rs2_v <= 'x;
            store_queue[i].r1 <= 1'b0;
            store_queue[i].r2 <= 1'b0;
            store_queue[i].ls_imm <= 'x;
            store_queue[i].age <= 'x;
            store_queue[i].speculation_bit <= 'x;
            store_queue[i].issued <= 1'b0;
            store_queue[i].address_computed <= 1'b0;
            store_queue[i].dmem_addr <= 'x;
            load_queue[i].ready_for_mem <= 'x;
        end

    end

    else begin
        if(action_load == none) begin
            front_load <= front_load;
            rear_load <= rear_load;
        end
        else if(action_load == push) begin
            rear_load <= (rear_load + 1) % l_q_depth;
            if(front_load == -1) front_load <= 0;
            else front_load <= front_load;
            for(int i=0; i< l_q_depth; i++) begin
                if(i == ((rear_load + 1) % l_q_depth) )
                begin
                    load_queue[(rear_load + 1) % l_q_depth] <= ls_q_inst1;
                    //load_store_queue[(rear + 1) % ls_q_depth].rob_id_dest <= rob_id_dest;
                end
            end
        end

        else if(action_load == 2'b10)begin
           // ls_q_o <= load_store_queue[front];
            load_queue[front_load].issued <= 1'b1;
            if(front_load == rear_load) begin
                front_load <= -1;
                rear_load <= -1;
            end
            else front_load <= (front_load + 1) % l_q_depth;
        end

        else if(action_load == 2'b11) begin
            load_queue[front_load].issued <= 1'b1;
            //load_queue[front_load].dmem_load_addr <= dmem_load_addr;
            front_load <= (front_load + 1) % l_q_depth;
            rear_load <= (rear_load + 1) % l_q_depth;
           // ls_q_o <= load_store_queue[front];
            for(int i=0; i< l_q_depth; i++) begin
                if(i == ((rear_load + 1) % l_q_depth) )
                begin
                    load_queue[(rear_load + 1) %l_q_depth] <= ls_q_inst1;
                    //load_store_queue[(rear + 1) % ls_q_depth].rob_id_dest <= rob_id_dest;
                end
            end
        end

        if(action_store == none) begin
            front_store <= front_store;
            rear_store <= rear_store;
        end
        else if(action_store == push) begin
            rear_store <= (rear_store + 1) % s_q_depth;
            if(front_store == -1) front_store <= 0;
            else front_store <= front_store;
            for(int i=0; i< s_q_depth; i++) begin
                if(i == ((rear_store + 1) % s_q_depth) )
                begin
                    store_queue[(rear_store + 1) % s_q_depth] <= ls_q_inst1;
                    //load_store_queue[(rear + 1) % ls_q_depth].rob_id_dest <= rob_id_dest;
                end
            end
        end

        else if(action_store == 2'b10)begin
           // ls_q_o <= load_store_queue[front];
            store_queue[front_store].issued <= 1'b1;
            if(front_store == rear_store) begin
                front_store <= -1;
                rear_store <= -1;
            end
            else front_store <= (front_store + 1) % s_q_depth;
        end

        else if(action_store == 2'b11) begin
            store_queue[front_store].issued <= 1'b1;
            front_store <= (front_store + 1) % s_q_depth;
            rear_store <= (rear_store + 1) % s_q_depth;
           // ls_q_o <= load_store_queue[front];
            for(int i=0; i< s_q_depth; i++) begin
                if(i == ((rear_store + 1) % s_q_depth) )
                begin
                    store_queue[(rear_store + 1) %s_q_depth] <= ls_q_inst1;
                    //load_store_queue[(rear + 1) % ls_q_depth].rob_id_dest <= rob_id_dest;
                end
            end
        end
        
        
        for(int i=0; i < s_q_depth; i++) begin
            if((store_queue[i].r1 == 1'b1) && (!store_queue[i].address_computed) && store_queue[i].valid) begin
                
                store_queue[i].dmem_addr <= address_array[i];
                store_queue[i].address_computed <= 1'b1;   
            end 
        end
        
        for(int i=0; i < l_q_depth; i++) begin
            if((load_queue[i].r1 == 1'b0) && (rob_data_bus[load_queue[i].rob_id].ready) && load_queue[i].valid) begin
                load_queue[i].rs1_v <= rob_data_bus[load_queue[i].rob_id].rd_data;
                load_queue[i].r1 <= 1'b1;
            end
        end

        for(int i=0; i < s_q_depth; i++) begin
            if((store_queue[i].r1 == 1'b0) && (rob_data_bus[store_queue[i].rob_id].ready) && store_queue[i].valid) begin
                store_queue[i].rs1_v <= rob_data_bus[store_queue[i].rob_id].rd_data;
                store_queue[i].r1 <= 1'b1;
            end
            
             if((store_queue[i].r2 == 1'b0) && (rob_data_bus[store_queue[i].rob_id2].ready) && store_queue[i].valid) begin
                store_queue[i].rs2_v <= rob_data_bus[store_queue[i].rob_id2].rd_data;
                store_queue[i].r2 <= 1'b1;
            end
        end
         
    end
end

endmodule : load_store
