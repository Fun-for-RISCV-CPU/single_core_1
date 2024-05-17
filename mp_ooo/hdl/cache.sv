module cache 
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

    logic [31:0]        address;
    logic [31:0]        address_next;
    logic [3:0]        rmask;
    logic [3:0]        rmask_next;
    logic [3:0]        wmask;
    logic [3:0]        wmask_next;
    logic [31:0]        wdata;
    logic [31:0]        wdata_next;

    logic [15:0][2:0]   plru;
    logic [15:0][2:0]   plru_next;

    // FSM state array
    logic   [2:0]      state;
    logic   [2:0]      state_next;

    // address information
    logic   [TAG_SIZE-1:0]      tag;
    logic   [4:0]       offset;
    logic   [N_SET-1:0]       set;       
    
    logic   [3:0]   web_i_data;
    logic   [3:0]   web_i_tag;
    logic   [3:0]   web_i;

    // output of sram
    logic [3:0][31-N_SET-4:0]        tag_array_out;
    logic [3:0][255:0]       data_array_out;
    logic [3:0]              valid_out;

    // logic [3:0][31:0]       data_array_out_shift;
    logic [31:0]       segmented_data;

    // sram inputs
    //logic [23:0]        tag_array_in;
    logic [255:0]       data_array_in;

    logic [31:0]        sram_write_mask;

    // cmp out
    logic [3:0]     cmpr_out;
    logic           hit;
    logic  [1:0]    way_to_write;

    logic [2:0]     plru_bits;

    logic   [31:0]  ufp_wdata_pass;
    logic           dirty;
    logic           set_dirty;

    assign ufp_wdata_pass = ufp_wdata;
    
    // Seperate address
    assign offset = address[4:0];
    // assign set = address[8:5];
    assign tag = address[31:5+N_SET];

    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (web_i_data[i]),
            .wmask0     (sram_write_mask),
            .addr0      (set),
            .din0       (data_array_in[255:0]),
            .dout0      (data_array_out[i][255:0])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (web_i_tag[i]),
            .addr0      (set),
            .din0       ({tag, set_dirty}),
            .dout0      (tag_array_out[i][TAG_SIZE:0])
        );
        ff_array #(.WIDTH(1)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (1'b0),
            .web0       (web_i[i]),
            .addr0      (set),
            .din0       (1'b1),
            .dout0      (valid_out[i])
        );
    end endgenerate

    always_ff @ (posedge clk) begin
        if (rst || branch_mispredict) begin
            state <= idle;
            address <= '0;
            rmask <= '0;
            wmask <= '0;
            plru <= plru_next;
        end else begin
            state <= state_next;
            plru <= plru_next;
            address <= address_next;
            wmask <= wmask_next;
            rmask <= rmask_next;
            wdata <= wdata_next;
        end
        
    end
    //always_ff

    always_comb begin
        web_i_data = 4'b1111;
        web_i_tag = 4'b1111;
        web_i = 4'b1111;
        ufp_resp = 1'b0;
        ufp_rdata = 'x;
        //state_next = '0;
        sram_write_mask = 'x;
        cmpr_out = 'x;
        hit = 1'b0;
        dfp_addr = 'x;
        dfp_read = 1'b0;
        dfp_write = 1'b0;
        dfp_wdata = 'x;
        way_to_write = 'x;
        plru_next = plru;
        set_dirty = 1'b0;
        dirty = 1'b0;

        data_array_in = '0;
        address_next = 'x;

        rmask_next = 'x;
        wmask_next = 'x;
        wdata_next = 'x;

        plru_bits = plru[set][2:0];
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

        if (state == idle) begin
            set = ufp_addr[4+N_SET:5];
        end else begin
            set = address[4+N_SET:5];
        end
        
        unique case (state)
            idle: begin
                if (ufp_rmask != 4'b0000 || ufp_wmask != 4'b0000 ) begin
                    state_next = compare;
                    address_next = ufp_addr;
                    rmask_next = ufp_rmask;
                    wmask_next = ufp_wmask;
                    wdata_next = ufp_wdata;
                end else begin
                    state_next = idle;
                end
            end
            compare: begin
                rmask_next = rmask;
                wmask_next = wmask;
                
                for (int i = 0; i < 4; i++) begin
                    cmpr_out[i] = (tag_array_out[i][TAG_SIZE:1] == tag);

                    if (cmpr_out[i] && valid_out[i]) begin
                        unique case (offset)
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
                        if (wmask != 4'b0000) begin
                            // write sram
                            web_i_data[i] = 1'b0;
                            web_i_tag[i] = 1'b0;
                            set_dirty = 1'b1;
                        end
                        hit = 1'b1;
                    end
                end
                sram_write_mask = {{28{1'b0}}, wmask} << (offset); 
                data_array_in = {{224{1'b0}}, wdata} << (offset*8); 
                
                if (hit) begin
                    // respond and back to idle
                    ufp_resp = 1'b1;
                    state_next = idle; 
                    // update plru
                    if (cmpr_out[0]) begin
                        plru_next[set][0] = 1'b1;
                        plru_next[set][1] = 1'b1;
                    end else if (cmpr_out[1]) begin
                        plru_next[set][0] = 1'b1;
                        plru_next[set][1] = 1'b0;
                    end else if (cmpr_out[2]) begin
                        plru_next[set][0] = 1'b0;
                        plru_next[set][2] = 1'b1;
                    end  else begin
                        plru_next[set][0] = 1'b0;
                        plru_next[set][2] = 1'b0;
                    end
                    address_next = ufp_addr;
                    wdata_next = ufp_wdata;
                end else begin
                    // dirty bit
                    if (tag_array_out[way_to_write][0]) begin
                        state_next = write_back;
                    end
                    else begin
                        state_next = allocate;
                    end
                    address_next = address;
                    wdata_next = wdata;
                end
            end
            allocate: begin
                rmask_next = rmask;
                wmask_next = wmask;
                address_next = address;
                wdata_next = wdata;
                dfp_addr = {address[31:5], 5'b00000};
                dfp_read = 1'b1;
                if (dfp_resp) begin
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
            write_back: begin
                rmask_next = rmask;
                wmask_next = wmask;
                address_next = address;
                wdata_next = wdata;
                // write to {tag(from tag array), set, 00000}
                dfp_addr = {tag_array_out[way_to_write][TAG_SIZE:1], set, 5'b00000};
                dfp_write = 1'b1;
                dfp_wdata = data_array_out[way_to_write];
                if (dfp_resp) begin                 
                    state_next = allocate; 
                end else begin
                    state_next = write_back;
                end
            end
            cache_wait : begin
                rmask_next = rmask;
                wmask_next = wmask;
                address_next = address;
                wdata_next = wdata;
                state_next = compare;
            end
            default: begin
                state_next = idle;
            end
            
        endcase
    end

endmodule
