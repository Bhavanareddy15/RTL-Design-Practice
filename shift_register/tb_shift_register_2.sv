module tb_shift_register_2;

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

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("tb_shift_register_2.vcd");
        $dumpvars(0, tb_shift_register_2);
    end

    task automatic check(input [WIDTH-1:0] exp_out, input exp_serial);
        logic ok;
        #1;
        ok = 1;
        if (parallel_out !== exp_out) begin
            $display("FAIL: rst_n=%b load=%b shift_en=%b dir=%b serial_in=%b parallel_in=%b -> parallel_out=%b (expected %b)",
                      rst_n, load, shift_en, dir, serial_in, parallel_in, parallel_out, exp_out);
            ok = 0;
        end
        if (serial_out !== exp_serial) begin
            $display("FAIL: rst_n=%b load=%b shift_en=%b dir=%b serial_in=%b parallel_in=%b -> serial_out=%b (expected %b)",
                      rst_n, load, shift_en, dir, serial_in, parallel_in, serial_out, exp_serial);
            ok = 0;
        end
        if (ok)
            $display("PASS: rst_n=%b load=%b shift_en=%b dir=%b serial_in=%b parallel_in=%b -> parallel_out=%b serial_out=%b",
                      rst_n, load, shift_en, dir, serial_in, parallel_in, parallel_out, serial_out);
        else
            errors++;
    endtask

    initial begin
        $display("Starting shift_register testbench...");

        rst_n       = 0;
        shift_en    = 0;
        dir         = 0;
        serial_in   = 0;
        parallel_in = 0;
        load        = 0;

        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        check(8'b0000_0000, 1'b0);

        parallel_in = 8'b1010_1101;
        load        = 1;
        @(posedge clk);
        check(8'b1010_1101, 1'b1);
        load = 0;

        dir       = 0;
        serial_in = 1;
        shift_en  = 1;
        @(posedge clk);
        check(8'b0101_1011, 1'b0);
        shift_en = 0;

        serial_in = 0;
        shift_en  = 1;
        @(posedge clk);
        check(8'b1011_0110, 1'b1);
        shift_en = 0;

        parallel_in = 8'b0001_1110;
        load        = 1;
        @(posedge clk);
        check(8'b0001_1110, 1'b0);
        load = 0;

        dir       = 1;
        serial_in = 1;
        shift_en  = 1;
        @(posedge clk);
        check(8'b1000_1111, 1'b1);
        shift_en = 0;

        @(posedge clk);
        check(8'b1000_1111, 1'b1);

        parallel_in = 8'b1100_0011;
        serial_in   = 1;
        dir         = 0;
        load        = 1;
        shift_en    = 1;
        @(posedge clk);
        check(8'b1000_0111, 1'b1);
        load     = 0;
        shift_en = 0;

        parallel_in = 8'b1100_0011;
        serial_in   = 0;
        dir         = 1;
        load        = 1;
        shift_en    = 1;
        @(posedge clk);
        check(8'b0110_0001, 1'b1);
        load     = 0;
        shift_en = 0;

        parallel_in = 8'b0110_1001;
        dir         = 0;
        serial_in   = 1;
        load        = 1;
        shift_en    = 0;
        @(posedge clk);
        serial_in = 0;
        check(8'b0110_1001, 1'b0);
        load = 0;

        shift_en  = 1;
        dir       = 0;
        serial_in = 1;
        rst_n     = 0;
        @(posedge clk);
        check(8'b0000_0000, 1'b0);
        rst_n    = 1;
        shift_en = 0;

        rst_n = 0;
        @(posedge clk);
        check(8'b0000_0000, 1'b0);
        rst_n = 1;

        #(CLK_PERIOD);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
