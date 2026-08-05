//design that detects the pattern 110101
`timescale 1ns/1ps

module pattern_detector(
    input logic clk,
    input logic areset_n,    // Asynchronous reset
    input logic in,
    output logic out);


    typedef enum {IDLE, S1, S11, S110, S1101, S11010, S110101} state_t;

    state_t state , next_state;

    always_ff @(posedge clk or negedge areset_n) begin
        if(!areset_n)
            state <= IDLE;
        else
            state <= next_state;
        end

    always_comb begin
        case(state)
        IDLE: if(in) next_state= S1;
            else next_state = IDLE;
        S1: if(in) next_state= S11;
            else next_state = IDLE;
        S11:if(!in) next_state= S110;
            else next_state = S11;
        S110:if(in) next_state= S1101;
            else next_state = IDLE;
        S1101:if(!in) next_state= S11010;
            else next_state = S11;
        S11010:if(in) next_state= S110101;
            else next_state = IDLE;
        S110101: if(in) next_state= S11;
            else next_state = IDLE;
        endcase

    end
    assign out = (state==S110101);

endmodule 