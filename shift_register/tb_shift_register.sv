module tb_shift_register;

    localparam WIDTH = 8;
    localparam CLK_PERIOD = 10;

    reg                  clk;
    reg                  rst_n;
    reg                  shift_en;
    reg                  dir;
    reg                  serial_in;
    reg  [WIDTH-1:0]     parallel_in;
    reg                  load;
    wire [WIDTH-1:0]     parallel_out;
    wire                 serial_out;

    int errors = 0;

    // DUT instantiation
    shift_register #(.WIDTH(WIDTH)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(shift_en),
        .dir(dir),
        .serial_in(serial_in),
        .parallel_in(parallel_in),
        .load(load),
        .parallel_out(parallel_out),
        .serial_out(serial_out)
    );

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Waveform dump
    initial begin
        $dumpfile("tb_shift_register.vcd");
        $dumpvars(0, tb_shift_register);
    end

    // Task to check parallel_out and serial_out against expected values
    task automatic check(input [WIDTH-1:0] exp_out, input exp_serial, input string label);
        logic ok;
        #1; // allow NBA updates to settle before sampling
        ok = 1;
        if (parallel_out !== exp_out) begin
            $display("FAIL [%s]: parallel_out=%b (expected %b)", label, parallel_out, exp_out);
            ok = 0;
        end
        if (serial_out !== exp_serial) begin
            $display("FAIL [%s]: serial_out=%b (expected %b)", label, serial_out, exp_serial);
            ok = 0;
        end
        if (ok)
            $display("PASS [%s]: parallel_out=%b serial_out=%b", label, parallel_out, serial_out);
        else
            errors++;
    endtask

    initial begin
        $display("Starting shift_register testbench...");

        // Initialize
        rst_n       = 0;
        shift_en    = 0;
        dir         = 0;
        serial_in   = 0;
        parallel_in = 0;
        load        = 0;

        // Apply reset
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        check(8'b0000_0000, 1'b0, "after reset");

        // Load parallel value
        parallel_in = 8'b1010_1101;
        load        = 1;
        @(posedge clk);
        #1 load = 0; // delay past the edge so the DUT samples load=1 first
        check(8'b1010_1101, 1'b1, "after parallel load");

        // Shift left, serial_in = 1
        dir       = 0;
        serial_in = 1;
        shift_en  = 1;
        @(posedge clk);
        #1 shift_en = 0; // delay past the edge so the DUT samples shift_en=1 first
        check(8'b0101_1011, 1'b0, "after 1 left shift, serial_in=1");

        // Shift left again, serial_in = 0
        serial_in = 0;
        shift_en  = 1;
        @(posedge clk);
        #1 shift_en = 0; // delay past the edge so the DUT samples shift_en=1 first
        check(8'b1011_0110, 1'b1, "after 2nd left shift, serial_in=0");

        // Reload and test right shift
        parallel_in = 8'b0001_1110;
        load        = 1;
        @(posedge clk);
        #1 load = 0; // delay past the edge so the DUT samples load=1 first
        check(8'b0001_1110, 1'b0, "after reload for right shift test");

        dir       = 1;
        serial_in = 1;
        shift_en  = 1;
        @(posedge clk);
        #1 shift_en = 0; // delay past the edge so the DUT samples shift_en=1 first
        check(8'b1000_1111, 1'b1, "after 1 right shift, serial_in=1");

        // Hold: shift_en = 0, value should not change
        @(posedge clk);
        check(8'b1000_1111, 1'b1, "hold, shift_en=0");

        // Simultaneous load + shift: the incoming parallel_in should be
        // shifted by one bit (using serial_in/dir) and that result stored,
        // not a plain load and not a shift of the old shift_reg.
        parallel_in = 8'b1100_0011;
        serial_in   = 1;
        dir         = 0;
        load        = 1;
        shift_en    = 1;
        @(posedge clk);
        #1 begin
            load     = 0;
            shift_en = 0;
        end
        check(8'b1000_0111, 1'b1, "load+shift simultaneously, dir=left");

        parallel_in = 8'b1100_0011;
        serial_in   = 0;
        dir         = 1;
        load        = 1;
        shift_en    = 1;
        @(posedge clk);
        #1 begin
            load     = 0;
            shift_en = 0;
        end
        check(8'b0110_0001, 1'b1, "load+shift simultaneously, dir=right");

        // Load only (shift_en de-asserted): serial_in changes both before
        // and during the load cycle, but must have zero effect since the
        // shift branches are never taken.
        parallel_in = 8'b0110_1001;
        dir         = 0;
        serial_in   = 1;
        load        = 1;
        shift_en    = 0;
        @(posedge clk);
        serial_in = 0; // serial_in toggles while load is still asserted
        #1 load = 0;   // delay past the edge so the DUT samples load=1 first
        check(8'b0110_1001, 1'b0, "load only, serial_in toggles, shift_en deasserted");

        // Reset again mid-operation
        rst_n = 0;
        @(posedge clk);
        #1 rst_n = 1; // delay past the edge so the DUT samples rst_n=0 first
        check(8'b0000_0000, 1'b0, "after mid-operation reset");

        #(CLK_PERIOD);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule

