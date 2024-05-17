module instruction_q_tb;
    //---------------------------------------------------------------------------------
    // Time unit setup.
    //---------------------------------------------------------------------------------
    timeunit 1ps;
    timeprecision 1ps;

    //---------------------------------------------------------------------------------
    // Waveform generation.
    //---------------------------------------------------------------------------------
   // initial begin
     //   $fsdbDumpfile("dump.fsdb");
       // $fsdbDumpvars(0, "+all");
    //end

    //---------------------------------------------------------------------------------
    // TODO: Declare cache port signals:
    //---------------------------------------------------------------------------------
    

    // cpu side signals, ufp -> upward facing port
      
      
    //---------------------------------------------------------------------------------
    // TODO: Generate a clock:
    //---------------------------------------------------------------------------------
  logic clk;
  
  always
begin
    #5;
    clk <= ~clk;
end

initial begin
clk <= 0;
end


    //---------------------------------------------------------------------------------
    // TODO: Write a task to generate reset:
    //---------------------------------------------------------------------------------

  logic rst;
  bit PASSED;
  
  function display_colored(string s, string color);
    unique case (color)
      "blue": $write("%c[1;34m", 27);
      "red": $write("%c[1;31m", 27);
      "green": $write("%c[1;32m", 27);
    endcase

    $display(s);
    $write("%c[0m",27);
  endfunction

 logic   [31:0] inst_in, inst_out;
 logic [1:0] action;
       logic empty, full;
       //int front, rear;
      //logic [5:0][31:0] instruction_arr;
       
  // TODO: Understand this reset task:
  task do_reset();
    rst = 1'b1; // Special case: using a blocking assignment to set rst
                // to 1'b1 at time 0.

    repeat (4) @(posedge clk); // Wait for 4 clock cycles.
    #3
    rst <= 1'b0; // Generally, non-blocking assignments when driving DUT
                 // signals.
  endtask : do_reset

 instruction_q dut(.*);
 
    initial begin
    do_reset();   
    action = 2'b00;
    inst_in = 32'haaaabbbb;
    repeat(5) @(posedge clk);
  //action = 2'b00;
   // inst_in = 32'haaaabbbb;
   //repeat(2) @(posedge clk);
    action = 2'b01;
    inst_in = 32'haaaaaaaa;
    @(posedge clk);
    inst_in = 32'hbabebabe;
    @(posedge clk);
    action = 2'b11;
    inst_in = 32'h11111111;
    @(posedge clk);
    inst_in = 32'h22222222;
    @(posedge clk);
     inst_in = 32'h33333333;
    @(posedge clk);
      inst_in = 32'h44444444;
    @(posedge clk);
     inst_in = 32'h44444444;
     @(posedge clk);
      inst_in = 32'h55555555;
       @(posedge clk);
      inst_in = 32'h66666666;
      @(posedge clk);
     inst_in = 32'haabbccdd;
     @(posedge clk);
      inst_in = 32'hffeeffee;
       @(posedge clk);
        action = 2'b01;
     inst_in = 32'hdeaddead;
     @(posedge clk);
     inst_in = 32'hdedeaabb;
     @(posedge clk);
     inst_in = 32'h12345678;
     @(posedge clk);
     inst_in = 32'hdedaaaaa;
     @(posedge clk);
     action = 2'b10;
     repeat(6) @(posedge clk);
    $finish;
  end

  //----------------------------------------------------------------------
  // Timeout.
  //----------------------------------------------------------------------
  initial begin
    #1s;
    $fatal("Timeout!");
  end

endmodule : instruction_q_tb