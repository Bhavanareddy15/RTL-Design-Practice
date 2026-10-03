`timescale 1ns/1ps

// v2: same FSM as fsm_design, hand-coded with one-hot state encoding.
// One flop per state; next-state logic is written per bit as
// "which states (and inputs) lead into this state".
module fsm_design_onehot(
    input logic clk,
    input logic areset_n,    // Asynchronous reset to state B
    input logic in,
    output logic out);

    localparam int B = 0;
    localparam int A = 1;

    localparam logic [1:0] RESET_STATE = 2'b01;   // state[B] = 1

    logic [1:0] state, next_state;

    always_ff @(posedge clk or negedge areset_n) begin
        if(!areset_n)
            state <= RESET_STATE;
        else
            state <= next_state;
        end

    always_comb begin
        // B is entered from B with in=1, or from A with in=0
        next_state[B] = (state[B] &  in) | (state[A] & ~in);
        // A is entered from A with in=1, or from B with in=0
        next_state[A] = (state[A] &  in) | (state[B] & ~in);
    end

    // Output decode is a single bit: no comparator needed
    assign out = state[B];

endmodule
