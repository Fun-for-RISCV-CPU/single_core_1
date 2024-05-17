module cache_w_adapter 
(   input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

     // mem side signals, ufp -> upward facing port
    output  logic   [31:0]      mem_addr, 
    output  logic               mem_read,
    output  logic               mem_write,
    output  logic   [63:0]      mem_wdata,
    input   logic               mem_ready,
    input   logic   [63:0]      mem_rdata,
    input   logic   [31:0]      mem_raddr,
    input   logic               mem_rvalid,
    output  logic               request,
    output  logic               write_complete,

    input   logic               branch_mispredict
);

    logic   [31:0]      cache_mem_addr;
    logic               cache_read;
    logic               cache_write;
    logic   [255:0]     cache_rdata;
    logic   [255:0]     cache_wdata;
    logic               resp;

    cache cache_inst(
        .clk(clk),
        .rst(rst),
        .ufp_addr(ufp_addr),
        .ufp_rmask(ufp_rmask),
        .ufp_wmask(ufp_wmask),
        .ufp_rdata(ufp_rdata),
        .ufp_wdata(ufp_wdata),
        .ufp_resp(ufp_resp),

        .dfp_addr(cache_mem_addr),
        .dfp_read(cache_read),
        .dfp_write(cache_write),
        .dfp_rdata(cache_rdata),
        .dfp_wdata(cache_wdata),
        .dfp_resp(resp),
        .branch_mispredict(branch_mispredict)
    );

    cache_adapter adapter_inst(
        .clk(clk),
        .rst(rst),
    
        // cache to adapter
        .cache_addr(cache_mem_addr), // Address from the cache
        .cache_read(cache_read), // 1 if cache reads from mem
        .cache_write(cache_write), // 1 is cache writes to mem
        .cache_rdata(cache_rdata), // data that cache wants to read
        .cache_wdata(cache_wdata), // data cache wants to write
        .cache_resp(resp), // response from the adapter to cache once coalsed data    
        
        // adapter to main mem
        .mem_addr(mem_addr),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_wdata(mem_wdata),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),
        .mem_raddr(mem_raddr),
        .mem_rvalid(mem_rvalid),
        .request(request),
        .write_complete(write_complete),
        .branch_mispredict(branch_mispredict)
    );

endmodule

module i_cache_w_adapter 
(   input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

     // mem side signals, ufp -> upward facing port
    output  logic   [31:0]      mem_addr,
    output  logic               mem_read,
    output  logic               mem_write,
    output  logic   [63:0]      mem_wdata,
    input   logic               mem_ready,
    input   logic   [63:0]      mem_rdata,
    input   logic   [31:0]      mem_raddr,
    input   logic               mem_rvalid,
    output  logic               request,
    output  logic               write_complete,

    input   logic               branch_mispredict
);

    logic   [31:0]      cache_mem_addr;
    logic               cache_read;
    logic               cache_write;
    logic   [255:0]     cache_rdata;
    logic   [255:0]     cache_wdata;
    logic               resp;

    pipelined_cache cache_inst(
        .clk(clk),
        .rst(rst),
        .ufp_addr(ufp_addr),
        .ufp_rmask(ufp_rmask),
        .ufp_wmask(ufp_wmask),
        .ufp_rdata(ufp_rdata),
        .ufp_wdata(ufp_wdata),
        .ufp_resp(ufp_resp),

        .dfp_addr(cache_mem_addr),
        .dfp_read(cache_read),
        .dfp_write(cache_write),
        .dfp_rdata(cache_rdata),
        .dfp_wdata(cache_wdata),
        .dfp_resp(resp),
        .branch_mispredict(branch_mispredict)
    );

    cache_adapter adapter_inst(
        .clk(clk),
        .rst(rst),
    
        // cache to adapter
        .cache_addr(cache_mem_addr), // Address from the cache
        .cache_read(cache_read), // 1 if cache reads from mem
        .cache_write(cache_write), // 1 is cache writes to mem
        .cache_rdata(cache_rdata), // data that cache wants to read
        .cache_wdata(cache_wdata), // data cache wants to write
        .cache_resp(resp), // response from the adapter to cache once coalsed data    
        
        // adapter to main mem
        .mem_addr(mem_addr),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_wdata(mem_wdata),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),
        .mem_raddr(mem_raddr),
        .mem_rvalid(mem_rvalid),
        .request(request),
        .write_complete(write_complete),
        .branch_mispredict(branch_mispredict)
    );

endmodule

module cache_adapter
import cache_types::*;
(
    input clk,
    input rst,

    // cache to adapter
    input   logic   [31:0]      cache_addr, // Address from the cache
    input   logic               cache_read, // 1 if cache reads from mem
    input   logic               cache_write, // 1 is cache writes to mem
    output  logic   [255:0]     cache_rdata, // data that cache wants to read
    input   logic   [255:0]     cache_wdata, // data cache wants to write
    output                      cache_resp, // response from the adapter to cache once coalsed data    
    
    // adapter to main mem
    output  logic   [31:0]      mem_addr,
    output  logic               mem_read,
    output  logic               mem_write,
    output  logic   [63:0]      mem_wdata,
    input   logic               mem_ready,
    input   logic   [63:0]      mem_rdata,
    input   logic   [31:0]      mem_raddr,
    input   logic               mem_rvalid,

    output  logic               request,
    output  logic               write_complete,
    input   logic               branch_mispredict

);

    logic [1:0]     response_counter;
    logic [1:0]     response_counter_next;
    logic [1:0]     state;
    logic [1:0]     state_next;
    logic [3:0][63:0]   aggregated_data;
    logic [3:0][63:0]   aggregated_data_next;
    logic               out_resp;
    logic [31:0]        cache_addr_latch;
    logic [31:0]        cache_addr_latch_next;

    assign cache_resp = out_resp;
    // states
    // idle
    // read: enters upon read, exits when response counter = 3
    // write: enters upon write, exits immediately? cannot get read data until write has occured?
    // reponse:


    always_ff @ (posedge clk) begin
        if (rst || (branch_mispredict && !(state == write))) begin
            state <= adapter_idle;
            response_counter <= '0;
            aggregated_data <= '0;
        end else begin
            state <= state_next;
            response_counter <= response_counter_next;
            aggregated_data <= aggregated_data_next;
            cache_addr_latch <= cache_addr_latch_next;
        end
    end

    // assign mem_read = cache_read;
    // assign mem_write = cache_write;
    assign request = cache_read || cache_write;

    always_comb begin
        out_resp = 1'b0;
        cache_rdata = 'x;
        mem_addr = 'x;
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_wdata = 'x;
        aggregated_data_next = aggregated_data;
        response_counter_next = '0;
        write_complete = 1'b0;
        cache_addr_latch_next = 'x;
        
        unique case (state)
            // transition to read if mem is ready and read
            // go to write if ready and cache to write
            adapter_idle : begin
                if (cache_read) begin
                    mem_read = 1'b1;
                    if (mem_ready) begin
                        mem_addr = cache_addr;
                        state_next = read;
                        // mem_read = 1'b1;
                    end else begin
                        state_next = adapter_idle;
                    end
                end
                else if (cache_write && !branch_mispredict) begin
                    mem_write = 1'b1;
                    if (mem_ready) begin
                        cache_addr_latch_next = cache_addr;
                        state_next = write;
                        // mem_write = 1'b1;
                        mem_wdata = cache_wdata[63:0];
                        mem_addr = cache_addr;
                        response_counter_next = response_counter + 2'd1;

                        aggregated_data_next[0][63:0] = cache_wdata[63:0];
                        aggregated_data_next[1][63:0] = cache_wdata[127:64];
                        aggregated_data_next[2][63:0] = cache_wdata[191:128];
                        aggregated_data_next[3][63:0] = cache_wdata[255:192];
                    end
                    else begin
                        state_next = adapter_idle;
                    end
                end
                else begin
                    state_next = adapter_idle;
                end
            end

            read : begin
                if (mem_rvalid) begin
                    if (mem_raddr == cache_addr) begin
                        if (response_counter == 2'b11) begin
                            aggregated_data_next[response_counter][63:0] = mem_rdata;
                            response_counter_next = 2'b00;
                            // state_next = response;
                            state_next = adapter_idle;
                            out_resp = 1'b1;
                            cache_rdata[63:0] = aggregated_data[0][63:0];
                            cache_rdata[127:64] = aggregated_data[1][63:0];
                            cache_rdata[191:128] = aggregated_data[2][63:0];
                            cache_rdata[255:192] = mem_rdata;
                        end else begin
                            aggregated_data_next[response_counter][63:0] = mem_rdata;
                            response_counter_next = response_counter + 2'd1;
                            state_next = read;
                        end
                    end 
                    else begin
                        state_next = read;
                        response_counter_next = response_counter;
                    end
                end else begin
                    response_counter_next = '0;
                    state_next = read;
                end
            end
            write : begin
                mem_write = 1'b1;
                cache_addr_latch_next = cache_addr_latch;
                if (mem_ready) begin
                    if (response_counter == 2'b11) begin
                        out_resp = 1'b1;
                        mem_addr = cache_addr_latch;
                        mem_wdata = aggregated_data[response_counter][63:0];
                        response_counter_next = 2'b00;
                        state_next = adapter_idle;
                        write_complete = 1'b1;
                    end
                    else begin
                        mem_addr = cache_addr_latch;
                        mem_wdata = aggregated_data[response_counter][63:0];
                        response_counter_next = response_counter + 2'd1;
                        state_next = write;
                    end
                end
                else begin
                    state_next = write;
                end
            end
            response : begin
                state_next = adapter_idle;
                out_resp = 1'b1;
                cache_rdata[63:0] = aggregated_data[0][63:0];
                cache_rdata[127:64] = aggregated_data[1][63:0];
                cache_rdata[191:128] = aggregated_data[2][63:0];
                cache_rdata[255:192] = aggregated_data[3][63:0];
            end

            default : begin
                state_next = adapter_idle;
            end

        endcase
    end

endmodule

