module tb_encoder;

    localparam INPUT_WIDTH = 8;
    localparam OUTPUT_WIDTH = $clog2(INPUT_WIDTH);

    reg  [INPUT_WIDTH-1:0]  inp;
    wire [OUTPUT_WIDTH:0]   binary;
    wire                    valid;

    int errors = 0;

    // DUT instantiation
    encoder #(.INPUT_WIDTH(INPUT_WIDTH)) dut (
        .inp(inp),
        .binary(binary),
        .valid(valid)
    );

    // Task to apply a stimulus and check result
    task automatic check(input [INPUT_WIDTH-1:0] test_inp,
                          input [OUTPUT_WIDTH:0] exp_binary,
                          input exp_valid);
        inp = test_inp;
        #5; // allow combinational logic to settle

        if (binary !== exp_binary || valid !== exp_valid) begin
            $display("FAIL: inp=%b -> binary=%0d valid=%b (expected binary=%0d valid=%b)",
                       test_inp, binary, valid, exp_binary, exp_valid);
            errors++;
        end else begin
            $display("PASS: inp=%b -> binary=%0d valid=%b",
                       test_inp, binary, valid);
        end
    endtask

    initial begin
        $display("Starting encoder testbench...");

        check(8'b0000_0000, 0, 1'b0);  // no bits set -> invalid
        check(8'b0000_0001, 0, 1'b1);  // bit 0
        check(8'b0000_0010, 1, 1'b1);  // bit 1
        check(8'b0000_0100, 2, 1'b1);  // bit 2
        check(8'b0001_0000, 4, 1'b1);  // bit 4
        check(8'b1000_0000, 7, 1'b1);  // bit 7 (highest priority)
        check(8'b1010_1010, 7, 1'b1);  // multiple bits, highest wins
        check(8'b0111_1111, 6, 1'b1);  // bits 0-6 set, highest is 6
        check(8'b0000_1001, 3, 1'b1);  // bits 0,3 set -> 3 wins

        #10;

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
