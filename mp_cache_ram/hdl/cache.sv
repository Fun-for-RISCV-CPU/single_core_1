module cache (
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
    input   logic           dfp_resp
);

logic [31:0] check_ufp_wdata;

assign check_ufp_wdata = ufp_wdata;

//state logic
logic [2:0] state, state_next;
// Logic needed for valid array
logic [3:0] valid_we, valid_in, valid_out;
logic [31:0] cache_wmask;
logic hit_found;

//Logic needed to access data and tag
logic   [3:0] set_index;
logic   [3:0][23:0] dirty_plus_tag_in, dirty_plus_tag_out;
logic  [3:0][255:0] data_cache_in, data_cache_out;
logic   [4:0] offset;
logic   [31:0] unprocessed_data;
logic dfp_resp_delayed;
logic   [15:0][2:0] plru_array, plru_array_next;
logic plru_array_update;
logic [15:0] plru_update_index;
logic [1:0] evicted_way, evicted_way_delayed;

    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (valid_we[i]),
            .wmask0     (cache_wmask),
            .addr0      (set_index),
            .din0       (data_cache_in[i]),
            .dout0      (data_cache_out[i])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (valid_we[i]),
            .addr0      (set_index),
            .din0       (dirty_plus_tag_in[i]),
            .dout0      (dirty_plus_tag_out[i])
        );
        ff_array #(.WIDTH(1)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (1'b0),
            .web0       (valid_we[i]),
            .addr0      (set_index),
            .din0       (valid_in[i]),
            .dout0      (valid_out[i])
        );
    end endgenerate
    
    always_ff @(posedge clk) begin
    if(state == 3'b101) evicted_way_delayed <= evicted_way_delayed;
    else evicted_way_delayed <= evicted_way;
end
    
always_ff @(posedge clk) begin
if(rst) begin
state <= 3'b000;
dfp_resp_delayed <= dfp_resp;
end
else begin
state <= state_next;
dfp_resp_delayed <= dfp_resp;
end
end

always_ff @(posedge clk) begin
if(rst) begin
plru_array <= 'x;
end
else begin
if(plru_array_update) begin
for(int j =0; j<16; j++) begin
if(plru_update_index[j] == 1'b1) begin
plru_array[j] <= plru_array_next[j];
end
else begin
plru_array[j] <= plru_array[j];
end
end
end
else begin
plru_array <= plru_array;
end
end
end

always_comb begin
state_next = state;
ufp_resp = 1'b0;
ufp_rdata = 'x;
cache_wmask = 'x;
dfp_addr = 'x;
dfp_read = 1'b0;
dfp_write = 1'b0;
dfp_wdata = 'x;
set_index = ufp_addr[8:5];
dirty_plus_tag_in = 'x;
data_cache_in = 'x;
valid_in = 'x;
hit_found = 1'b0;
plru_array_next = 'x;
evicted_way = 'x;
valid_we = 4'b1111;
unprocessed_data = 'x;
plru_array_update = 1'b0;
offset = {ufp_addr[4:2], 2'b0};
plru_update_index = 16'h0000;
case (state)
3'b000: begin 
if((ufp_rmask == '0) && (ufp_wmask == '0)) begin
state_next = 3'b001;
end
else begin
state_next = 3'b010;
end
plru_update_index = 16'h0000;
end
3'b001: begin
plru_update_index = 16'h0000;
ufp_resp = 1'b0;
if((ufp_rmask == '0) && (ufp_wmask == '0)) begin
state_next = 3'b001;
end
else begin
state_next = 3'b010;
end
end

3'b010: begin
// add wmask condition later and check dirty bit
unprocessed_data = 'x;
ufp_rdata = 'x;
state_next = 3'b011;
if(ufp_rmask != 0) begin
for(int i = 0; i<4; i++) begin
if((valid_out[i]) && ({ufp_addr[31:9]} == dirty_plus_tag_out[i][22:0] ) ) begin
hit_found = 1'b1;
plru_array_update = 1'b1;
plru_update_index[set_index] = 1'b1;
if(i==0) begin
plru_array_next[set_index][2] = 1'b0;
plru_array_next[set_index][1] = 1'b0;
plru_array_next[set_index][0] = plru_array[set_index][0];
end
else if(i==1)begin
plru_array_next[set_index][2] = 1'b0;
plru_array_next[set_index][1] = 1'b1;
plru_array_next[set_index][0] = plru_array[set_index][0];
end
else if(i==2)begin
plru_array_next[set_index][2] = 1'b1;
plru_array_next[set_index][0] = 1'b0;
plru_array_next[set_index][1] = plru_array[set_index][1];
end
else begin
plru_array_next[set_index][2] = 1'b1;
plru_array_next[set_index][0] = 1'b1;
plru_array_next[set_index][1] = plru_array[set_index][1];
end


unique case (offset)
'd0: unprocessed_data = data_cache_out[i][31:0];
'd4: unprocessed_data = data_cache_out[i][63:32];
'd8: unprocessed_data = data_cache_out[i][95:64];
'd12: unprocessed_data = data_cache_out[i][127:96];
'd16: unprocessed_data = data_cache_out[i][159:128];
'd20: unprocessed_data = data_cache_out[i][191:160];
'd24: unprocessed_data = data_cache_out[i][223:192];
'd28: unprocessed_data = data_cache_out[i][255:224];
default: unprocessed_data = 'x;
endcase
for (int i = 0; i < 4; i++) begin
                if (ufp_rmask[i]) begin
                    ufp_rdata[i*8+:8] = unprocessed_data[i*8+:8];
                end else begin
                    ufp_rdata[i*8+:8] = 'x;
                end
            end
  ufp_resp = 1'b1;
  state_next = 3'b001;      
end
end

if(!hit_found) begin
unique case (plru_array[set_index])
3'b000, 3'b010: begin
if(dirty_plus_tag_out[3][23] == 1'b1) begin
state_next = 3'b101;
evicted_way = 2'b11;
end 
end
3'b001, 3'b011: begin
if(dirty_plus_tag_out[2][23] == 1'b1) begin
state_next = 3'b101;
evicted_way = 2'b10;
end
end
3'b100, 3'b101: begin
if(dirty_plus_tag_out[1][23] == 1'b1)begin
 state_next = 3'b101;
 evicted_way = 2'b01;
 end
end
3'b110, 3'b111: begin
if(dirty_plus_tag_out[0][23] == 1'b1)begin
 state_next = 3'b101;
 evicted_way = 2'b00;
 end
end
default: begin
state_next = 3'b011;
evicted_way = 'x;
end
endcase
end
end

else begin

for(int i = 0; i<4; i++) begin
if((valid_out[i]) && ({ufp_addr[31:9]} == dirty_plus_tag_out[i][22:0] ) ) begin
valid_we[i] = 1'b0;
valid_in[i] = 1'b1;
hit_found = 1'b1;
dirty_plus_tag_in[i][23]=1'b1;
dirty_plus_tag_in[i][22:0] = ufp_addr[31:9];
plru_array_update = 1'b1;
plru_update_index[set_index] = 1'b1;
if(i==0) begin
plru_array_next[set_index][2] = 1'b0;
plru_array_next[set_index][1] = 1'b0;
plru_array_next[set_index][0] = plru_array[set_index][0];
end
else if(i==1)begin
plru_array_next[set_index][2] = 1'b0;
plru_array_next[set_index][1] = 1'b1;
plru_array_next[set_index][0] = plru_array[set_index][0];
end
else if(i==2)begin
plru_array_next[set_index][2] = 1'b1;
plru_array_next[set_index][0] = 1'b0;
plru_array_next[set_index][1] = plru_array[set_index][1];
end
else begin
plru_array_next[set_index][2] = 1'b1;
plru_array_next[set_index][0] = 1'b1;
plru_array_next[set_index][1] = plru_array[set_index][1];
end

            
unique case (offset)
'd0: begin
data_cache_in[i][31:0] = ufp_wdata;
cache_wmask = {28'h0000000, ufp_wmask};
end
'd4: begin
data_cache_in[i][63:32] = ufp_wdata;
cache_wmask = {24'h000000,ufp_wmask, 4'h0};
end
'd8: begin
data_cache_in[i][95:64] = ufp_wdata;
cache_wmask = {20'h00000,ufp_wmask, 8'h00};
end
'd12: begin
data_cache_in[i][127:96] = ufp_wdata;
cache_wmask = {16'h0000,ufp_wmask,12'h000};
 end
'd16: begin
data_cache_in[i][159:128] = ufp_wdata;
cache_wmask = {12'h000,ufp_wmask,16'h0000};
 end
'd20: begin
data_cache_in[i][191:160] = ufp_wdata;
cache_wmask = {8'h00,ufp_wmask,20'h00000};
 end
'd24: begin
data_cache_in[i][223:192] = ufp_wdata;
cache_wmask = {4'h0,ufp_wmask,24'h000000};
end
'd28: begin
data_cache_in[i][255:224] = ufp_wdata;
cache_wmask = {ufp_wmask,28'h0000000};
end
default: begin
data_cache_in[i] = 'x;
cache_wmask = 'x;
end
endcase
 ufp_resp = 1'b1;
 state_next = 3'b001;

end
end

if(!hit_found) begin
unique case (plru_array[set_index])
3'b000, 3'b010: begin
if(dirty_plus_tag_out[3][23] == 1'b1) begin
state_next = 3'b101;
evicted_way = 2'b11;
end 
end
3'b001, 3'b011: begin
if(dirty_plus_tag_out[2][23] == 1'b1) begin
state_next = 3'b101;
evicted_way = 2'b10;
end
end
3'b100, 3'b101: begin
if(dirty_plus_tag_out[1][23] == 1'b1)begin
 state_next = 3'b101;
 evicted_way = 2'b01;
 end
end
3'b110, 3'b111: begin
if(dirty_plus_tag_out[0][23] == 1'b1)begin
 state_next = 3'b101;
 evicted_way = 2'b00;
 end
end
default: begin
state_next = 3'b011;
evicted_way = 'x;
end
endcase
end
end
end

3'b100: begin
state_next = 3'b010;
end

3'b101: begin
dfp_write = 1'b1;
dfp_wdata = data_cache_out[evicted_way_delayed];
dfp_addr = {dirty_plus_tag_out[evicted_way_delayed][22:0],set_index,5'b00000};
if(dfp_resp) state_next = 3'b011;
else state_next = 3'b101;
end

3'b011: begin
plru_update_index = 16'h0000;
dfp_read = 1'b1;
dfp_addr = ufp_addr & 32'hffffffe0;
unique case (dfp_resp)
1'b0: state_next = 3'b011;

1'b1: begin
cache_wmask = 32'hffffffff;
state_next = 3'b100;


if(plru_array[set_index][2]==1'b0) begin
unique case(plru_array[set_index][0])
1'b0: begin
valid_we[3] = 1'b0;
data_cache_in[3] = dfp_rdata;
valid_in[3] = 1'b1;
dirty_plus_tag_in[3] = {1'b0, ufp_addr[31:9]};
end
1'b1: begin
valid_we[2] = 1'b0;
data_cache_in[2] = dfp_rdata;
valid_in[2] = 1'b1;
dirty_plus_tag_in[2] = {1'b0, ufp_addr[31:9]};
end

default: begin
valid_we[2] = 1'b0;
data_cache_in[2] = dfp_rdata;
valid_in[2] = 1'b1;
dirty_plus_tag_in[2] = {1'b0, ufp_addr[31:9]};
end
endcase
end

else if(plru_array[set_index][2]==1'b1) begin
unique case(plru_array[set_index][1])
1'b0: begin
valid_we[1] = 1'b0;
data_cache_in[1] = dfp_rdata;
valid_in[1] = 1'b1;
dirty_plus_tag_in[1] = {1'b0, ufp_addr[31:9]};
end
1'b1: begin
valid_we[0] = 1'b0;
data_cache_in[0] = dfp_rdata;
valid_in[0] = 1'b1;
dirty_plus_tag_in[0] = {1'b0, ufp_addr[31:9]};
end
default: begin
valid_we[0] = 1'b0;
data_cache_in[0] = dfp_rdata;
valid_in[0] = 1'b1;
dirty_plus_tag_in[0] = {1'b0, ufp_addr[31:9]};
end
endcase
end

else begin
valid_we[0] = 1'b0;
data_cache_in[0] = dfp_rdata;
valid_in[0] = 1'b1;
dirty_plus_tag_in[0] = {1'b0, ufp_addr[31:9]};
end


end
default: begin
valid_we = 4'b1111;
data_cache_in = 'x;
valid_in = 'x;
dirty_plus_tag_in = 'x;
cache_wmask = 'x;
end
endcase
end

endcase
end

endmodule
