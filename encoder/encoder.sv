module encoder #(parameter INPUT_WIDTH = 8, parameter OUTPUT_WIDTH= $clog2(INPUT_WIDTH))(
    input [INPUT_WIDTH-1:0] inp,
    output reg [OUTPUT_WIDTH:0] binary,
    output reg valid
);

integer i;

always @(*) begin
    binary = 0;
    valid= 1'b0;
    for(i=0; i<INPUT_WIDTH; i++) begin
        if(inp[i]) begin
            binary = i[OUTPUT_WIDTH:0];
            valid = 1'b1;
        end
    end

end

endmodule

