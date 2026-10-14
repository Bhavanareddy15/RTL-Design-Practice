// Priority encoder — literal casez, fixed at INPUT_WIDTH=8
//
// Not parameterized: case-item widths and patterns must be compile-time
// literals.  Written to test whether explicit casez pattern matching
// (no serial `found` dependency) produces better synthesis QoR than
// the scan-up for-loop in encoder.sv or the found-flag version in
// encoder_casez.sv.

module encoder_casez_fixed (
    input  wire [7:0] inp,
    output reg  [2:0] binary,
    output wire       valid
);

always_comb begin
    casez (inp)
        8'b1???????: binary = 3'd7;
        8'b01??????: binary = 3'd6;
        8'b001?????: binary = 3'd5;
        8'b0001????: binary = 3'd4;
        8'b00001???: binary = 3'd3;
        8'b000001??: binary = 3'd2;
        8'b0000001?: binary = 3'd1;
        8'b00000001: binary = 3'd0;
        default:     binary = 3'd0;
    endcase
end

assign valid = |inp;

endmodule
