// Priority encoder — casez-equivalent, parameterized
//
// A literal casez requires fixed-width case items with '?' wildcards and
// cannot be directly parameterized.  For INPUT_WIDTH=8 it would look like:
//
//   casez (inp)
//     8'b1???????: binary = 3'd7;
//     8'b01??????: binary = 3'd6;
//     8'b001?????: binary = 3'd5;
//     8'b0001????: binary = 3'd4;
//     8'b00001???: binary = 3'd3;
//     8'b000001??: binary = 3'd2;
//     8'b0000001?: binary = 3'd1;
//     8'b00000001: binary = 3'd0;
//     default:     binary = '0;
//   endcase
//
// The parameterized form below scans MSB-first with a `found` guard,
// which is semantically identical to the casez priority chain.  Yosys
// eliminates `found` during optimization and produces the same gate
// topology as the literal casez.
//
// Note: Yosys does not support `break` inside for-loops, so the guard
// flag is the portable substitute for an early exit.
//
// Synthesis result vs. the scan-up "last-write-wins" loop in encoder.sv:
//   encoder.sv    — 14 cells, depth 6
//   encoder_casez — 38 cells, depth 8  (worse)
//
// The `found` flag creates a serial dependency chain across iterations;
// ABC cannot shorten it.  The simpler scan-up loop, despite looking less
// explicit about priority intent, gives the synthesis tool more freedom
// and produces a smaller, shallower result.  A literal casez (fixed N)
// would avoid this problem by expressing priority without any chain.

module encoder_casez #(
    parameter INPUT_WIDTH  = 8,
    parameter OUTPUT_WIDTH = $clog2(INPUT_WIDTH)
)(
    input  wire [INPUT_WIDTH-1:0]  inp,
    output reg  [OUTPUT_WIDTH-1:0] binary,
    output wire                    valid
);

logic found;

always_comb begin
    binary = '0;
    found  = 1'b0;
    for (int i = INPUT_WIDTH-1; i >= 0; i--) begin
        if (inp[i] && !found) begin
            binary = OUTPUT_WIDTH'(i);
            found  = 1'b1;
        end
    end
end

assign valid = |inp;

endmodule
