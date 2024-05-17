module pipelined_cache 
import cache_types::*;
(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp,
    input   logic           branch_mispredict
);
    logic [15:0][2:0]   plru;
    logic [15:0][2:0]   plru_next;

    // FSM state array
    logic   [2:0]      state;
    logic   [2:0]      state_next;
    
    // Write enables   
    logic   [3:0]   web_i_data;
    logic   [3:0]   web_i_tag;
    logic   [3:0]   web_i;

    // output of sram
    logic [3:0][31-N_SET-4:0]        tag_array_out; // fix
    logic [3:0][255:0]       data_array_out;
    logic [3:0]              valid_out;

    // logic [3:0][255:0]       data_array_out_shift;
    logic   [31:0]          segmented_data;

    // sram inputs
    //logic [23:0]        tag_array_in;
    logic [255:0]       data_array_in;

    logic [31:0]        sram_write_mask;

    // cmp out
    logic [3:0]     cmpr_out;
    logic           hit;

    logic           dirty;
    logic           set_dirty;
    
    // for pipeline
    logic stalled;
    cache_stage_reg_t           cache_reg;
    cache_stage_reg_t           cache_reg_next;

    logic   [TAG_SIZE-1:0]      tag;
    logic   [4:0]               offset;
    logic   [N_SET-1:0]         set; 
    logic   [N_SET-1:0]         index_set; 
    
    // cmp out
    logic  [1:0]    way_to_write;
    logic [2:0]     plru_bits;

    logic [2:0]     enter;
    
    stage_1_cache stage_1_inst(
        // .clk(clk),
        // .rst(rst),
    
        // cpu side signals, ufp -> upward facing port
        .ufp_addr(ufp_addr),
        .ufp_rmask(ufp_rmask),
        .ufp_wmask(ufp_wmask),
        .ufp_wdata(ufp_wdata),
        .stall(stalled),
        .tag(tag),      
        .offset(offset),
        .set(set),   
        .cache_reg(cache_reg), 
        .cache_reg_next(cache_reg_next)
    );

    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (web_i_data[i]),
            .wmask0     (sram_write_mask),
            .addr0      (index_set),
            .din0       (data_array_in[255:0]),
            .dout0      (data_array_out[i][255:0])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (web_i_tag[i]),
            .addr0      (index_set),
            .din0       ({set_dirty, cache_reg.tag}),
            .dout0      (tag_array_out[i][TAG_SIZE:0])
        );
        ff_array #(.WIDTH(1)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (1'b0),
            .web0       (web_i[i]),
            .addr0      (index_set),
            .din0       (1'b1),
            .dout0      (valid_out[i])
        );
    end endgenerate

    always_ff @ (posedge clk) begin
        if (rst) begin
            state <= compare;
            plru <= plru_next;
            cache_reg <= '0;
        end else if (branch_mispredict) begin
            state <= compare;
            plru <= plru_next;
            cache_reg <= '0;
        end else begin
            state <= state_next;
            plru <= plru_next;
            cache_reg <= cache_reg_next;
        end
        
    end
    //always_ff

    always_comb begin
        web_i_data = {4{1'b1}};
        web_i_tag = {4{1'b1}};
        web_i = {4{1'b1}};
        ufp_resp = 1'b0;
        ufp_rdata = 'x;
        //state_next = '0;
        sram_write_mask = {32{1'b0}};
        cmpr_out = 4'b0000;
        hit = 1'b0;
        dfp_addr = 'x;
        dfp_read = 1'b0;
        dfp_write = 1'b0;
        dfp_wdata = 'x;
        plru_next = plru;
        set_dirty = 1'b0;
        dirty = 1'b0;
        way_to_write = 'x;

        data_array_in = 'x;
        enter = 'x;

        plru_bits = plru[cache_reg.set][2:0];
        if (plru_bits[0] == 0) begin
            if(plru_bits[1] == 0) begin
                way_to_write = 2'b00;
            end else begin
                way_to_write = 2'b01;
            end
        end else begin
            if(plru_bits[2] == 0) begin
                way_to_write = 2'b10;
            end else begin
                way_to_write = 2'b11;
            end
        end
        
        unique case (state)
            compare: begin
                if (cache_reg.valid) begin
                    enter = 3'b001;
                    // sram_write_mask = {{28{1'b0}}, cache_reg.wmask} << (offset); 
                    // data_array_in = {{224{1'b0}}, cache_reg.wdata} << (offset*8); 
                    
                    for (int i = 0; i < 4; i++) begin
                        cmpr_out[i] = (tag_array_out[i][TAG_SIZE-1:0] == cache_reg.tag);

                        if (cmpr_out[i] && valid_out[i]) begin
                            unique case (cache_reg.offset)
                            'd0: segmented_data = data_array_out[i][31:0];
                            'd4: segmented_data = data_array_out[i][63:32];
                            'd8: segmented_data = data_array_out[i][95:64];
                            'd12: segmented_data = data_array_out[i][127:96];
                            'd16: segmented_data = data_array_out[i][159:128];
                            'd20: segmented_data = data_array_out[i][191:160];
                            'd24: segmented_data = data_array_out[i][223:192];
                            'd28: segmented_data = data_array_out[i][255:224];
                            default: segmented_data = 'x;
                            endcase
                            ufp_rdata = segmented_data;
                            if (cache_reg.wmask != 4'b0000) begin
                                 // write sram
                                web_i_data[i] = 1'b0;
                                web_i_tag[i] = 1'b0;
                                set_dirty = 1'b1;
                            end
                            hit = 1'b1;
                        end
                    end
                    
                    if (hit) begin
                        enter = 3'b010;
                        // respond and back to idle
                        stalled = 1'b0;
                        ufp_resp = 1'b1;
                        state_next = compare; 
                        // update plru
                        if (cmpr_out[0]) begin
                            plru_next[cache_reg.set][0] = 1'b1;
                            plru_next[cache_reg.set][1] = 1'b1;
                        end else if (cmpr_out[1]) begin
                            plru_next[cache_reg.set][0] = 1'b1;
                            plru_next[cache_reg.set][1] = 1'b0;
                        end else if (cmpr_out[2]) begin
                            plru_next[cache_reg.set][0] = 1'b0;
                            plru_next[cache_reg.set][2] = 1'b1;
                        end  else begin
                            plru_next[cache_reg.set][0] = 1'b0;
                            plru_next[cache_reg.set][2] = 1'b0;
                        end
                    end else begin
                        // dirty bit
                        enter = 3'b011;
                        stalled = 1'b1;
                        // if (tag_array_out[way_to_write][TAG_SIZE-1]) begin
                        //     state_next = write_back;
                        // end
                        // else begin
                        state_next = allocate;
                        // end
                    end
                end else begin
                    enter = 3'b100;
                    state_next = compare;
                    stalled = 1'b0;
                end
                
            end
            allocate: begin
                dfp_addr = {cache_reg.tag, cache_reg.set, 5'b00000};
                dfp_read = 1'b1;
                stalled = 1'b1;
                if (dfp_resp && !branch_mispredict) begin
                    // check which way to write
                    
                    // need to write valid bit
                    // need to write tag to sram
                    // need to write data to sram
                    data_array_in = dfp_rdata;
                    sram_write_mask = {32{1'b1}};   
                    web_i[way_to_write] = 1'b0;
                    web_i_tag[way_to_write] = 1'b0;
                    web_i_data[way_to_write] = 1'b0;

                    state_next = cache_wait; 
                end else begin
                    state_next = allocate;
                end
            end
            // write_back: begin
            //     stalled = 1'b1;
            //     // write to {tag(from tag array), set, 00000}
            //     dfp_addr = {tag_array_out[way_to_write][TAG_SIZE:1], cache_reg.set, 5'b00000};
            //     dfp_write = 1'b1;
            //     dfp_wdata = data_array_out[way_to_write];
            //     if (dfp_resp) begin                 
            //         state_next = allocate; 
            //     end else begin
            //         state_next = write_back;
            //     end
            // end
            cache_wait : begin
                stalled = 1'b1;
                state_next = compare;
            end
            default: begin
                stalled = 1'b0;
                state_next = idle;
            end
            
        endcase
        
        if (stalled && !branch_mispredict) begin
            index_set = cache_reg.set;
        end else begin
            index_set = set;
        end
    end

endmodule


module stage_1_cache 
import cache_types::*;
(
    // input   logic           clk,
    // input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]              ufp_addr,
    input   logic   [3:0]               ufp_rmask,
    input   logic   [3:0]               ufp_wmask,
    input   logic   [31:0]              ufp_wdata,
    input   logic                       stall,
    output  logic   [TAG_SIZE-1:0]      tag,
    output  logic   [4:0]               offset,
    output  logic   [N_SET-1:0]         set,   
    input   cache_stage_reg_t           cache_reg,
    output  cache_stage_reg_t           cache_reg_next
);

    // logic [31:0]        address;
    // logic [31:0]        address_next;
    // logic [3:0]         rmask;
    // logic [3:0]         rmask_next;
    // logic [3:0]         wmask;
    // logic [3:0]         wmask_next;
    // logic [31:0]        wdata;
    // logic [31:0]        wdata_next;

    // address information   
    
    // Seperate address
    assign offset = ufp_addr[4:0];
    assign set = ufp_addr[4+N_SET:5];
    assign tag = ufp_addr[31:5+N_SET];

    // always_ff @ (posedge clk) begin
    //     if (rst) begin
    //         address <= '0;
    //         rmask <= '0;
    //         wmask <= '0;
    //         wdata <= '0;
    //     end else begin
    //         address <= address_next;
    //         rmask <= rmask_next;
    //         wmask <= wmask_next;
    //         wdata <= wdata_next;
    //     end
    // end

    always_comb begin
        // address_next = 'x;
        // rmask_next = 'x;
        // wmask_next = 'x;
        // wdata_next = 'x;

        if (stall) begin
            cache_reg_next = cache_reg;
        end else begin
            if (ufp_rmask != 4'b0000 || ufp_wmask != 4'b0000) begin
                // address_next = ufp_addr;
                // rmask_next = ufp_rmask;
                // wmask_next = ufp_wmask;
                // wdata_next = ufp_wdata;
                cache_reg_next.tag = tag;
                cache_reg_next.set = set;
                cache_reg_next.offset = offset;
                cache_reg_next.valid = 1'b1;
                cache_reg_next.wmask = ufp_wmask;
                cache_reg_next.wdata = ufp_wdata;
            end else begin
                cache_reg_next.tag = tag;
                cache_reg_next.set = set;
                cache_reg_next.offset = offset;
                cache_reg_next.valid = 1'b0;
                cache_reg_next.wmask = ufp_wmask;
                cache_reg_next.wdata = ufp_wdata;
            end
        end
        
    end

endmodule