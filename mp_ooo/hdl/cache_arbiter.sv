// wait until transaction complete (response from cache)
// read only one cycle
// write need counter or get data from cache

module cache_arbiter
import cache_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           i_cache_request,
    input   logic           d_cache_request,
    input   logic   [31:0]  i_cache_addr,
    input   logic           i_cache_read,
    input   logic           i_cache_write,
    input   logic   [63:0]  i_cache_wdata, 
    output  logic           i_cache_ready,

    input   logic   [31:0]  d_cache_addr,
    input   logic           d_cache_read,
    input   logic           d_cache_write,
    input   logic   [63:0]  d_cache_wdata, 
    output   logic           d_cache_ready,

    output logic   [31:0]      bmem_addr,
    output logic               bmem_read,
    output logic               bmem_write,
    output logic   [63:0]      bmem_wdata,
    input logic                 bmem_ready,
    input logic                 write_complete
);
    logic   last_transaction;
    logic   last_transaction_next;
    logic  state, state_next;

    always_ff @ (posedge clk) begin
        if (rst) begin
            last_transaction <= 1'b0;
            state <= arb_idle;
        end
        else begin
            last_transaction <= last_transaction_next;
            state <= state_next;
        end
    end

    // idle state
    // read state
    // write state
    logic arb_choice; // 1'b1 give priority to dcache 1'b0 give priorty to dcache

    // assign arb_choice = 1'b1;

    // output mux
    always_comb begin
        if (arb_choice) begin
            bmem_addr = i_cache_addr;
            bmem_read = i_cache_read && bmem_ready;
            bmem_write = i_cache_write && bmem_ready;
            bmem_wdata = i_cache_wdata;
            i_cache_ready = bmem_ready;
            d_cache_ready = 1'b0;
        end else begin
            bmem_addr = d_cache_addr;
            bmem_read = d_cache_read && bmem_ready;
            bmem_write = d_cache_write && bmem_ready;
            bmem_wdata = d_cache_wdata;
            i_cache_ready = 1'b0;
            d_cache_ready = bmem_ready;
        end
    end

    // assign arb_choice = 1'b1;

    // Priority selection
    always_comb begin
        last_transaction_next = last_transaction;
        arb_choice = 1'b1;

        unique case (state)
            arb_idle : begin
                if (i_cache_request && d_cache_request) begin
                    if (last_transaction == 1'b0) begin
                        arb_choice = 1'b1;
                        // icache always read
                        state_next = arb_idle;
                        if (bmem_ready) begin
                            last_transaction_next = 1'b1;
                        end
                        
                    end else begin
                        arb_choice = 1'b0;
                        if (d_cache_read) begin
                            state_next = arb_idle;
                            if (bmem_ready) begin
                                last_transaction_next = 1'b0;
                            end
                        end
                        else if (d_cache_write) begin // dcache write
                            state_next = arb_write;
                            last_transaction_next = 1'b0;
                        end else begin
                            state_next = arb_idle;
                        end
                    end
                end else if (i_cache_request || d_cache_request) begin
                    if (i_cache_read) begin
                        arb_choice = 1'b1;
                        state_next = arb_idle;
                    end else if (d_cache_read) begin
                        arb_choice = 1'b0;
                        state_next = arb_idle;
                    end else if (d_cache_write) begin // dcache write
                        arb_choice = 1'b0;
                        state_next = arb_write;
                    end else begin
                        state_next = arb_idle;
                    end
                    
                end else begin
                    state_next = arb_idle;
                end
                
            end
            arb_write : begin
                arb_choice = 1'b0;
                if (write_complete) begin
                    state_next = arb_idle;
                end else begin
                    state_next = arb_write;
                end
            end

            default : begin
                state_next = arb_idle;
            end
        endcase
    end

endmodule