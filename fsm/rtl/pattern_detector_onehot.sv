//design that detects the pattern 110101
// v2: same FSM as pattern_detector, hand-coded with one-hot state encoding.
// One flop per state; next-state logic is written per bit as
// "which states (and inputs) lead into this state".
`timescale 1ns/1ps

module pattern_detector_onehot(
    input logic clk,
    input logic areset_n,    // Asynchronous reset
    input logic in,
    output logic out);

    // Bit position of each state in the one-hot vector
    localparam int IDLE_BIT    = 0;
    localparam int S1_BIT      = 1;
    localparam int S11_BIT     = 2;
    localparam int S110_BIT    = 3;
    localparam int S1101_BIT   = 4;
    localparam int S11010_BIT  = 5;
    localparam int S110101_BIT = 6;
    localparam int NUM_STATES  = 7;

    localparam logic [NUM_STATES-1:0] ST_IDLE = 1 << IDLE_BIT;

    logic [NUM_STATES-1:0] state, next_state;

    always_ff @(posedge clk or negedge areset_n) begin
        if(!areset_n)
            state <= ST_IDLE;
        else
            state <= next_state;
        end

    always_comb begin
        // in=0 where the bits seen so far no longer match any prefix of 110101
        next_state[IDLE_BIT]    = ~in & (state[IDLE_BIT] | state[S1_BIT] | state[S110_BIT]
                                       | state[S11010_BIT] | state[S110101_BIT]);
        next_state[S1_BIT]      =  in &  state[IDLE_BIT];
        // in=1 where the longest matching prefix becomes "11"
        next_state[S11_BIT]     =  in & (state[S1_BIT] | state[S11_BIT]
                                       | state[S1101_BIT] | state[S110101_BIT]);
        next_state[S110_BIT]    = ~in &  state[S11_BIT];
        next_state[S1101_BIT]   =  in &  state[S110_BIT];
        next_state[S11010_BIT]  = ~in &  state[S1101_BIT];
        next_state[S110101_BIT] =  in &  state[S11010_BIT];
    end

    assign out = state[S110101_BIT];

endmodule
