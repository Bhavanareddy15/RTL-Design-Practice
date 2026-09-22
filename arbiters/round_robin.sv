module round_robin (
  input  logic       clk,
  input  logic       reset,

  input  logic [3:0] req_i,
  output logic [3:0] gnt_o
);

  logic [3:0] prior_reg;    // one-hot pointer: lowest-priority slot for the next arbitration
  logic [3:0] mask;         // thermometer mask: pointer bit and every bit above it
  logic [3:0] masked_req;

  assign mask       = ~(prior_reg - 1'b1);
  assign masked_req = req_i & mask;
  assign gnt_o       = masked_req ? (masked_req & (~masked_req + 1'b1))
                                   : (req_i      & (~req_i      + 1'b1));

  always_ff @(posedge clk) begin
    if (reset)
      prior_reg <= 4'b0001;
    else if (|req_i)
      prior_reg <= {gnt_o[2:0], gnt_o[3]};  // rotate granted bit up by one, wraps automatically
  end

endmodule