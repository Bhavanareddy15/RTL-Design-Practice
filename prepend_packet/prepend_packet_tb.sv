module testbench;
    localparam STDIN = 'h8000_0000;

    reg start_of_packet_in = 'b0;
    reg end_of_packet_in = 'b0;
    reg [63:0] data_in = 'b0;
    reg [2:0] byte_count_in = 'b0;

    wire start_of_packet_out;
    wire end_of_packet_out;
    wire [63:0] data_out;
    wire [2:0] byte_count_out;

    reg clk = 'b1;
    always #5 clk = !clk;

    reg rst = 'b1;
    initial #10 rst = 'b0;

    initial#400 $finish;

    integer ret;
    always @(posedge clk) begin
        #1; ret = $fscanf(STDIN, "%h %h %h %h",
            start_of_packet_in, end_of_packet_in, data_in, byte_count_in);
    end

    always @(posedge clk) begin
        $display("%h %h %h %h",
            start_of_packet_out, end_of_packet_out, data_out, byte_count_out);
    end

    prepend_packet_header dut_inst (
        .clk_i             (clk),
        .rst_i             (rst),
        .start_of_packet_i (start_of_packet_in),
        .end_of_packet_i   (end_of_packet_in),
        .data_i            (data_in),
        .byte_count_i      (byte_count_in),
        .start_of_packet_o (start_of_packet_out),
        .end_of_packet_o   (end_of_packet_out),
        .data_o            (data_out),
        .byte_count_o      (byte_count_out)
    );
endmodule
