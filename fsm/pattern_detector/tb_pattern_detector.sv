//------------------------------------------------------------------------
// Testbench for fsm_design (110101 sequence detector)

//------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_pattern_detector;

    // DUT I/O
    logic clk;
    logic areset_n;
    logic in;
    logic out;

    int   num_checks   = 0;
    int   num_errors    = 0;

    // Instantiate DUT
    pattern_detector dut (
        .clk       (clk),
        .areset_n  (areset_n),
        .in        (in),
        .out       (out)
    );

    //--------------------------------------------------------------
    // Clock: 10ns period
    //--------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    //--------------------------------------------------------------
    // Reference model
    // Mirrors the DUT's states/transitions but with:
    //   - reset/init state = IDLE (waiting for first '1')
    //   - out driven combinationally as a Moore output
    //--------------------------------------------------------------
    typedef enum {IDLE, S1, S11, S110, S1101, S11010, S110101} state_t;
    state_t ref_state, ref_next;
    logic   ref_out;

    always_comb begin
        case(ref_state)
            IDLE   : ref_next = state_t'(in ? S1     : IDLE);
            S1     : ref_next = state_t'(in ? S11    : IDLE);
            S11    : ref_next = state_t'(in ? S11    : S110);
            S110   : ref_next = state_t'(in ? S1101  : IDLE);
            S1101  : ref_next = state_t'(in ? S11    : S11010);
            S11010 : ref_next = state_t'(in ? S110101: IDLE);
            S110101: ref_next = state_t'(in ? S11    : IDLE);
            default: ref_next = IDLE;
        endcase
    end

    assign ref_out = (ref_state == S110101);

    always_ff @(posedge clk or negedge areset_n) begin
        if (!areset_n)
            ref_state <= IDLE;
        else
            ref_state <= ref_next;
    end

    //--------------------------------------------------------------
    // Scoreboard: compare DUT out vs reference model out,
    // one clock after every applied input.
    //--------------------------------------------------------------
    task automatic check_out(string tag);
        num_checks++;
        if (out !== ref_out) begin
            num_errors++;
            $display("[%0t] MISMATCH (%s): dut.out=%b  ref_out=%b  dut.state=%s  ref_state=%s",
                       $time, tag, out, ref_out, dut.state.name(), ref_state.name());
        end else begin
            $display("[%0t] OK       (%s): out=%b  dut.state=%s",
                       $time, tag, out, dut.state.name());
        end
    endtask

    //--------------------------------------------------------------
    // Drive one input bit on the rising edge, then check on the
    // next rising edge once state/out have settled.
    //--------------------------------------------------------------
    task automatic apply_bit(logic b, string tag = "");
        in = b;
        @(posedge clk);
        #1; // allow combinational logic / NBA updates to settle
        check_out(tag);
    endtask

    task automatic apply_seq(string bits, string tag);
        foreach (bits[i])
            apply_bit(bits[i] == "1", $sformatf("%s[%0d]", tag, i));
    endtask

    task automatic do_reset();
        areset_n = 0;
        in       = 0;
        repeat (2) @(posedge clk);
        #1;
        areset_n = 1;
        @(posedge clk);
        #1;
    endtask

    //--------------------------------------------------------------
    // Stimulus
    //--------------------------------------------------------------
    initial begin
        $display("=== Starting fsm_design testbench ===");

        do_reset();

        // 1. Simple non-matching sequence
        apply_seq("101010", "no_match");

        // 2. Single clean occurrence of the pattern
        apply_seq("110101", "single_match");

        // 3. Back-to-back non-overlapping occurrence
        apply_seq("110101110101", "back_to_back");

        // 4. Overlapping occurrences: 1101011010101...
        //    "110101" appears starting at index 0 and again with overlap
        apply_seq("1101011010101", "overlapping");

        // 5. Long run of 1's / 0's (corner cases)
        apply_seq("1111111111", "all_ones");
        apply_seq("0000000000", "all_zeros");

        // 6. Mid-sequence async reset
        apply_seq("1101", "partial_before_reset");
        do_reset();
        apply_seq("101", "after_reset_no_match");

        // 7. Randomized bits, self-checked every cycle
        for (int i = 0; i < 200; i++)
            apply_bit($urandom_range(0,1), $sformatf("rand[%0d]", i));

        $display("=== Testbench complete: %0d checks, %0d errors ===",
                   num_checks, num_errors);
        if (num_errors == 0)
            $display("*** ALL CHECKS PASSED ***");
        else
            $display("*** %0d MISMATCHES — see log above (likely caused by the undriven `out` signal / reset-state bug in the DUT) ***", num_errors);

        $finish;
    end

    //--------------------------------------------------------------
    // Waveform dump
    //--------------------------------------------------------------
    initial begin
        $dumpfile("tb_pattern_detector.vcd");
        $dumpvars(0, tb_pattern_detector);
    end

endmodule