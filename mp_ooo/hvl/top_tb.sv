import "DPI-C" function string getenv(input string env_name);

module top_tb;

    timeunit 1ps;
    timeprecision 1ps;

    int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;

    int timeout = 10000000; // in cycles, change according to your needs
    //int timeout = 100000; // in cycles, change according to your needs
    int num_cycles = 0;
    int num_instr = 0;
    int branch_counter = 0;

    int branch_mis_counter = 0;
    int reservation_full = 0;
    int rob_full = 0;
    int store_full = 0;
    int load_full = 0;
    int imem_miss = 0;
    int dmem_miss = 0;
    int dmem_call = 0;
    int load_foward = 0;
    int dispatch = 0;
    int i_queue_empty = 0;
    // Dmem call
    // num instruction = imem calls

    // int imem_stall = 0;
    // int dmem_stall = 0;
    int fetch_stall = 0;
    int i_queue_full = 0;


    // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
    // mem_itf mem_itf_i(.*);
    // mem_itf mem_itf_d(.*);
    // magic_dual_port mem(.itf_i(mem_itf_i), .itf_d(mem_itf_d));

    // Single memory port connection when caches are integrated into design (CP3 and after)
    banked_mem_itf bmem_itf(.*);
    banked_memory banked_memory(.itf(bmem_itf));

    mon_itf mon_itf(.*);
    monitor monitor(.itf(mon_itf));

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
        // .imem_addr      (mem_itf_i.addr),
        // .imem_rmask     (mem_itf_i.rmask),
        // .imem_rdata     (mem_itf_i.rdata),
        // .imem_resp      (mem_itf_i.resp),

        // .dmem_addr      (mem_itf_d.addr),
        // .dmem_rmask     (mem_itf_d.rmask),
        // .dmem_wmask     (mem_itf_d.wmask),
        // .dmem_rdata     (mem_itf_d.rdata),
        // .dmem_wdata     (mem_itf_d.wdata),
        // .dmem_resp      (mem_itf_d.resp)

        // Single memory port connection when caches are integrated into design (CP3 and after)
        .bmem_addr(bmem_itf.addr),
        .bmem_read(bmem_itf.read),
        .bmem_write(bmem_itf.write),
        .bmem_wdata(bmem_itf.wdata),
        .bmem_ready(bmem_itf.ready),
        .bmem_raddr(bmem_itf.raddr),
        .bmem_rdata(bmem_itf.rdata),
        .bmem_rvalid(bmem_itf.rvalid)
    );

    `include "../../hvl/rvfi_reference.svh"

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        if (dut.branch_mispredict == 1'b1 && (dut.btb.pc_at_commit.branch_inst || dut.btb.pc_at_commit.jal_inst)) begin
            branch_mis_counter = branch_mis_counter + 1;    
        end
        // Check wait state
        if (dut.instruction_cache.cache_inst.state == 3'b100) begin
            imem_miss = imem_miss + 1;
        end

        if (dut.data_cache.cache_inst.state == 3'b100) begin
            dmem_miss = dmem_miss + 1;
        end

        if (dut.reservation_full) begin
            reservation_full = reservation_full + 1;
        end

        if (dut.rob_full) begin
            rob_full = rob_full + 1;
        end

        if (dut.full_load) begin
            load_full = load_full + 1;
        end

        if (dut.full_store) begin
            store_full = store_full + 1;
        end

        if (dut.dmem_rmask != 4'b0000 || dut.dmem_wmask != 4'b0000) begin
            dmem_call = dmem_call + 1;
        end

        if ((dut.btb.pc_at_commit.branch_inst || dut.btb.pc_at_commit.jal_inst)&& dut.btb.pc_at_commit.ready) begin
            branch_counter = branch_counter + 1;
        end

        if ((dut.load_store.load_res_station[0].data_forwarded)) begin
            load_foward = load_foward + 1;
        end
        // for (int i = 0; i < 4; i++) begin
        //     if (dut.load_store.storeq_data_forwarded[i]) begin
        //         load_foward = load_foward + 1;
        //     end
        // end
        if(dut.valid_inst) begin
            dispatch = dispatch + 1;
        end

        if(dut.fetch_unit_inst.fetch_stage_2.empty) begin
            i_queue_empty = i_queue_empty + 1;
        end

        for (int unsigned i=0; i < 8; ++i) begin
            if (mon_itf.halt[i]) begin
                $display("Branch counter: %d", branch_counter);
                $display("Branch mispredict: %d", branch_mis_counter);
                $display("Imem miss: %d", imem_miss);
                $display("Dmem miss: %d", dmem_miss);
                $display("Dmem call: %d", dmem_call);
                $display("Reservation_full: %d", reservation_full);
                $display("Rob full: %d", rob_full);
                $display("Load full: %d", load_full);
                $display("Store full: %d", store_full);
                $display("Load forward: %d", load_foward);
                $display("Inst count: %d", real'(monitor.inst_count));
                $display("Cycle count: %d", monitor.cycle_count);
                $display("Dispatch: %d", dispatch);
                $display("Queue empty: %d", i_queue_empty);
                $display("Issue: %d", i_queue_empty);

                $finish;
            end
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        if (mon_itf.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        // if (mem_itf_i.error != 0) begin
        //     repeat (5) @(posedge clk);
        //     $finish;
        // end
        // if (mem_itf_d.error != 0) begin
        //     repeat (5) @(posedge clk);
        //     $finish;
        // end
        if (bmem_itf.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        // if (mem_itf_i.error != 0) begin
        //     repeat (5) @(posedge clk);
        //     $finish;
        // end
        // if (mem_itf_d.error != 0) begin
        //     repeat (5) @(posedge clk);
        //     $finish;
        // end
        timeout <= timeout - 1;
    end

endmodule
