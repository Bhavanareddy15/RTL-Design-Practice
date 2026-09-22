module tb_fixed_pri_arbiter;

    localparam N = 8;

    logic [N-1:0] req;
    wire  [N-1:0] gnt;

    int errors = 0;

    // DUT instantiation
    fixed_pri_arbiter #(.N(N)) dut (
        .req (req),
        .gnt (gnt)
    );

    // Waveform dump
    initial begin
        $dumpfile("tb_fixed_pri_arbiter.vcd");
        $dumpvars(0, tb_fixed_pri_arbiter);
    end

    // Reference model: fixed priority, LSB (bit0) is highest priority,
    // so the expected grant is simply the lowest set bit of req.
    function automatic [N-1:0] expected_gnt(input [N-1:0] r);
        expected_gnt = r & (~r + 1'b1);
    endfunction

    task automatic check(input string label);
        logic [N-1:0] exp;
        #1; // allow combinational logic to settle
        exp = expected_gnt(req);
        if (gnt !== exp) begin
            $display("FAIL [%s]: req=%b gnt=%b (expected %b)", label, req, gnt, exp);
            errors++;
        end
        else begin
            $display("PASS [%s]: req=%b gnt=%b", label, req, gnt);
        end
    endtask

    initial begin
        $display("Starting fixed_pri_arbiter testbench...");

        // No requests
        req = '0;
        check("no requests");

        // Single requester on each bit
        for (int i = 0; i < N; i++) begin
            req = (1 << i);
            check($sformatf("single req, bit%0d", i));
        end

        // Two requesters: lowest-index one should always win
        req = 8'b0000_0110; // bits 1 & 2
        check("bits 1 & 2, expect bit1");

        req = 8'b1000_0001; // bits 0 & 7
        check("bits 0 & 7, expect bit0");

        req = 8'b0100_0100; // bits 2 & 6
        check("bits 2 & 6, expect bit2");

        // All requesters active: lowest bit (bit0) should win
        req = 8'b1111_1111;
        check("all req, expect bit0");

        // All but the lowest bit active: bit1 should win
        req = 8'b1111_1110;
        check("all but bit0, expect bit1");

        // Only the highest bit active
        req = 8'b1000_0000;
        check("only bit7, expect bit7");

        // Sparse pattern
        req = 8'b0101_0100;
        check("sparse pattern, expect lowest set bit");

        // Back to idle
        req = '0;
        check("back to idle");

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
