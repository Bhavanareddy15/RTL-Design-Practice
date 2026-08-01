`timescale 1ns/1ps

module fsm_tb;

    logic clk;
    logic areset;   // active-low: 0 = in reset, 1 = normal operation
    logic in;
    logic out;

    fsm_design dut (
        .clk      (clk),
        .areset_n (areset),
        .in       (in),
        .out      (out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    logic ref_state;
    logic ref_out;

    always @(posedge clk or negedge areset) begin
        if (!areset)
            ref_state <= 1'b1;
        else
            ref_state <= (in == 1'b0) ? ~ref_state : ref_state;
    end

    assign ref_out = ref_state;

    int errors = 0;
    int checks = 0;

    task automatic check_out(string phase);
        checks++;
        if (out !== ref_out) begin
            errors++;
            $display("[%0t] ERROR (%s): out=%b expected=%b (in=%b areset=%b)",
                      $time, phase, out, ref_out, in, areset);
        end
    endtask

    always @(negedge clk) begin
        if (areset) check_out("posedge-clk");
    end

    always @(negedge areset) begin
        #1;
        check_out("async-reset");
    end

    initial begin
        int rand_in;
        int rand_pick;
        int rand_delay;

        $display("---- FSM testbench start ----");
        in     = 1'b0;
        areset = 1'b0;              // assert reset
        ref_state = 1'b1;

        @(negedge clk);
        @(negedge clk);
        areset = 1'b1;              // release reset

        in = 1'b1; repeat (3) @(negedge clk); check_out("dir1-hold-B");
        in = 1'b0; @(negedge clk); check_out("dir2-B-to-A");
        in = 1'b1; repeat (3) @(negedge clk); check_out("dir3-hold-A");
        in = 1'b0; @(negedge clk); check_out("dir4-A-to-B");

        in = 1'b1; @(negedge clk); #2;
        areset = 1'b0;               // assert reset
        #3;
        areset = 1'b1;               // release reset

        for (int i = 0; i < 200; i++) begin
            rand_in = $urandom_range(0,1);
            in = rand_in[0];
            rand_pick = $urandom_range(0,19);
            if (rand_pick == 0) begin
                areset = 1'b0;        // assert reset
                rand_delay = $urandom_range(1,4);
                #(rand_delay);
                areset = 1'b1;        // release reset
            end
            @(negedge clk);
        end

        $display("---- FSM testbench done: %0d checks, %0d errors ----",
                  checks, errors);
        if (errors == 0)
            $display("*** TEST PASSED ***");
        else
            $display("*** TEST FAILED ***");

        $finish;
    end

    property p_legal_out;
        @(posedge clk) disable iff (!areset) (out === 1'b0 || out === 1'b1);
    endproperty
    assert property (p_legal_out)
        else $error("out took an illegal value");

    initial begin
        $dumpfile("fsm_tb.vcd");
        $dumpvars(0, fsm_tb);
    end

endmodule