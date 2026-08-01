`timescale 1ns/1ps

module fsm_design(
    input logic clk,
    input logic areset_n,    // Asynchronous reset to state B
    input logic in,
    output logic out);

    typedef enum {A, B} state_t;

    state_t state, next_state;

    always_ff @(posedge clk or negedge areset_n) begin
        if(!areset_n)
            state <= B;
        else
            state <= next_state;
        end
    
    always_comb begin
        case(state)
        B: begin 
            if (in)
                next_state = B;
            else
                next_state = A;
            end
        A: begin
            if (in)
                next_state = A;
            else
                next_state = B;
            end
        endcase
    end

    assign out = (state == B)? 1:0;


endmodule

