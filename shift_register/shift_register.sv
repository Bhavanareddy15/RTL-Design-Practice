module shift_register #(
    parameter WIDTH = 8
)(
    input                   clk,
    input                   rst_n,      // active-low synchronous reset
    input                   shift_en,   // enable shifting
    input                   dir,        // 0 = shift left, 1 = shift right
    input                   serial_in,  // bit shifted in
    input  [WIDTH-1:0]      parallel_in,
    input                   load,       // load parallel_in into register
    output [WIDTH-1:0]      parallel_out,
    output                  serial_out
);

    // TODO: declare internal register(s)
    logic [WIDTH-1:0] shift_reg;

    // TODO: always block for synchronous load/shift/reset logic
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            shift_reg<=0;
        end
        else if(load) begin
            shift_reg<= parallel_in;

        end
        else if(shift_en & !dir) begin
           shift_reg <= {shift_reg[WIDTH-2:0],serial_in};
        end
        else if(shift_en & dir) begin
           shift_reg <= {serial_in, shift_reg[WIDTH-1:1]};
        end
        else begin
            shift_reg<=shift_reg;
        end
    end


    // TODO: assign parallel_out and serial_out
    assign parallel_out = shift_reg;
    assign serial_out = dir? shift_reg[0]: shift_reg[7];

endmodule
