module tb_round_robin;

    localparam CLK_PERIOD = 10;

    logic        clk;
    logic        reset;
    logic [3:0]  req_i;
    wire  [3:0]  gnt_o;

    int errors = 0;

    // Reference model state (mirrors the DUT's mask/rotate architecture)
    logic [3:0] ref_prior;
    logic [3:0] exp_gnt;

    // DUT instantiation
    round_robin dut (
        .clk   (clk),
        .reset (reset),
        .req_i (req_i),
        .gnt_o (gnt_o)
    );

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Waveform dump
    initial begin
        $dumpfile("tb_round_robin.vcd");
        $dumpvars(0, tb_round_robin);
    end

    // Reference round-robin grant function: thermometer-masks req_i to the
    // pointer position and above, grants the lowest bit in that window, and
    // falls back to the lowest bit of the unmasked req_i (wraparound) if
    // nothing at/above the pointer is requesting. Mirrors the DUT's formula.
    function automatic [3:0] compute_grant(input [3:0] req, input [3:0] prior_onehot);
        logic [3:0] mask;
        logic [3:0] masked_req;
        mask       = ~(prior_onehot - 4'b0001);
        masked_req = req & mask;
        compute_grant = masked_req ? (masked_req & (~masked_req + 4'b0001))
                                    : (req        & (~req        + 4'b0001));
    endfunction

    // Rotates a one-hot grant up by one position, wrapping bit3 to bit0.
    function automatic [3:0] next_prior(input [3:0] grant);
        next_prior = {grant[2:0], grant[3]};
    endfunction

    // exp_gnt is combinational (mirrors the DUT's `assign gnt_o = ...`);
    // only ref_prior is a register (mirrors the DUT's prior_reg).
    assign exp_gnt = compute_grant(req_i, ref_prior);

    always_ff @(posedge clk) begin
        if (reset)
            ref_prior <= 4'b0001;
        else if (|req_i)
            ref_prior <= next_prior(exp_gnt);
    end

    task automatic check(input string label);
        #1; // allow NBA updates to settle before sampling
        if (gnt_o !== exp_gnt) begin
            $display("FAIL [%s]: req_i=%b gnt_o=%b (expected %b)", label, req_i, gnt_o, exp_gnt);
            errors++;
        end
        else begin
            $display("PASS [%s]: req_i=%b gnt_o=%b", label, req_i, gnt_o);
        end
    endtask

    initial begin
        $display("Starting round_robin testbench...");

        // Initialize
        reset = 1;
        req_i = 4'b0000;

        @(posedge clk);
        @(posedge clk);
        reset = 0;
        check("after reset");

        // Single requester on each channel
        req_i = 4'b0001;
        @(posedge clk); check("single req, bit0");

        req_i = 4'b0010;
        @(posedge clk); check("single req, bit1");

        req_i = 4'b0100;
        @(posedge clk); check("single req, bit2");

        req_i = 4'b1000;
        @(posedge clk); check("single req, bit3");

        // No request: grant should deassert (combinational output)
        req_i = 4'b0000;
        @(posedge clk); check("no request, deasserted");

        // Same requester holds its request across multiple cycles
        req_i = 4'b0001;
        @(posedge clk); check("bit0 requests again");
        @(posedge clk); check("bit0 still requesting");

        // All requesters active simultaneously, several cycles in a row
        req_i = 4'b1111;
        @(posedge clk); check("all req, cycle 1");
        @(posedge clk); check("all req, cycle 2");
        @(posedge clk); check("all req, cycle 3");
        @(posedge clk); check("all req, cycle 4");
        @(posedge clk); check("all req, cycle 5 (wraps)");

        // Two simultaneous requesters, non-adjacent bits
        req_i = 4'b0101;
        @(posedge clk); check("req bits 0 & 2, pass 1");
        @(posedge clk); check("req bits 0 & 2, pass 2");

        // Request pattern changes mid-stream
        req_i = 4'b1010;
        @(posedge clk); check("req bits 1 & 3, pass 1");
        req_i = 4'b0001;
        @(posedge clk); check("switch to bit0 only");

        // Reset mid-operation
        req_i = 4'b1111;
        @(posedge clk);
        reset = 1;
        @(posedge clk);
        reset = 0;
        check("after mid-operation reset");

        #(CLK_PERIOD);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
