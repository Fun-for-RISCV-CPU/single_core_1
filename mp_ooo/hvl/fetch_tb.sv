module fetch_tb;

    timeunit 1ps;
    timeprecision 1ps;

    int clock_half_period_ps = 5;

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;
    int counter;

    int timeout = 1000; // in cycles, change according to your needs

    // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
    mem_itf mem_itf_i(.*);
    mem_itf mem_itf_d(.*);
    magic_dual_port mem(.itf_i(mem_itf_i), .itf_d(mem_itf_d));

    logic imem_mask;
    logic halt;
    logic   [63:0]  inst_out;
    logic           reservation_full;
    logic           rob_full;
    logic   [31:0]  branch_t;
    logic           valid_inst;

    assign mem_itf_d.wmask = 4'b0000;
    assign mem_itf_d.rmask = 4'b0000;
    // Single memory port connection when caches are integrated into design (CP3 and after)
    /*
    bmem_itf bmem_itf(.*);
    blocking_burst_memory burst_memory(.itf(bmem_itf));
    */

    // mon_itf mon_itf(.*);    
    // monitor monitor(.itf(mon_itf));

    fetch_unit dut(
        .clk            (clk),
        .rst            (rst),

        // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
        .branch_mispredict(1'b0),
        .branch_target(branch_t),
        .imem_addr(mem_itf_i.addr),
        .imem_rmask(mem_itf_i.rmask),
        .imem_rdata(mem_itf_i.rdata),
        .imem_resp(mem_itf_i.resp && imem_mask),
        .reservation_full(reservation_full),
        .rob_full(1'b0),
        .valid_inst(valid_inst),
        .inst_out(inst_out)

        // Single memory port connection when caches are integrated into design (CP3 and after)
        /*
        .bmem_addr      (bmem_itf.addr),
        .bmem_read      (bmem_itf.read),
        .bmem_write     (bmem_itf.write),
        .bmem_rdata     (bmem_itf.rdata),
        .bmem_wdata     (bmem_itf.wdata),
        .bmem_resp      (bmem_itf.resp)
        */

    );

    // `include "../../hvl/rvfi_reference.svh"

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        counter = 0;
        halt = 1'b0;
        rst = 1'b1;
        reservation_full = 1'b0;
        branch_t = 'x;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        // if (mon_itf.halt) begin
        //     $finish;
        // end

        counter <= counter + 1;
        if (counter == 20) begin
            imem_mask <= 1'b0;
        end
        else begin
            imem_mask <= 1'b1;
        end

        if (counter == 30 ||  counter == 31 || counter == 32) begin
            reservation_full <= 1'b1;
        end
        else begin
            reservation_full <= 1'b0;
        end

        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        // if (mon_itf.error != 0) begin
        //     repeat (5) @(posedge clk);
        //     $finish;
        // end
        if (mem_itf_i.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        if (mem_itf_d.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        timeout <= timeout - 1;
    end

endmodule
