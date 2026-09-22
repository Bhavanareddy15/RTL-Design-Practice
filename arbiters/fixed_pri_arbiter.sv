module fixed_pri_arbiter #(
  parameter N = 32
) (
  input   logic [N-1:0]  req,
  output  logic [N-1:0]  gnt
);

logic [N-1:0] higher_pri_req;
  assign higher_pri_req[0] = 1'b0; //LSB has the highest priority

genvar i;
generate
  for (i = 0; i < N-1; i++) begin : gen_higher_pri
    assign higher_pri_req[i+1] = higher_pri_req[i] | req[i];
  end
endgenerate

assign gnt = req[N-1:0] & ~higher_pri_req[N-1:0];

endmodule 