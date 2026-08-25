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

    // Task to check parallel_out against expected value
    task automatic check(input [WIDTH-1:0] exp_out, input string label);
        #1; // allow NBA updates to settle before sampling
        if (parallel_out !== exp_out) begin
            $display("FAIL [%s]: parallel_out=%b (expected %b)", label, parallel_out, exp_out);
            errors++;
        end else begin
            $display("PASS [%s]: parallel_out=%b", label, parallel_out);
        end
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
        check(8'b0000_0000, "after reset");

        // Load parallel value
        parallel_in = 8'b1010_1101;
        load        = 1;
        @(posedge clk);
        #1 load = 0; // delay past the edge so the DUT samples load=1 first
        check(8'b1010_1101, "after parallel load");

        // Shift left, serial_in = 1
        dir       = 0;
        serial_in = 1;
        shift_en  = 1;
        @(posedge clk);
        #1 shift_en = 0; // delay past the edge so the DUT samples shift_en=1 first
        check(8'b0101_1011, "after 1 left shift, serial_in=1");

        // Shift left again, serial_in = 0
        serial_in = 0;
        shift_en  = 1;
        @(posedge clk);
        #1 shift_en = 0; // delay past the edge so the DUT samples shift_en=1 first
        check(8'b1011_0110, "after 2nd left shift, serial_in=0");

        // Reload and test right shift
        parallel_in = 8'b0001_1110;
        load        = 1;
        @(posedge clk);
        #1 load = 0; // delay past the edge so the DUT samples load=1 first
        check(8'b0001_1110, "after reload for right shift test");

        dir       = 1;
        serial_in = 1;
        shift_en  = 1;
        @(posedge clk);
        #1 shift_en = 0; // delay past the edge so the DUT samples shift_en=1 first
        check(8'b1000_1111, "after 1 right shift, serial_in=1");

        // Hold: shift_en = 0, value should not change
        @(posedge clk);
        check(8'b1000_1111, "hold, shift_en=0");

        // Reset again mid-operation
        rst_n = 0;
        @(posedge clk);
        #1 rst_n = 1; // delay past the edge so the DUT samples rst_n=0 first
        check(8'b0000_0000, "after mid-operation reset");

        #(CLK_PERIOD);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule

