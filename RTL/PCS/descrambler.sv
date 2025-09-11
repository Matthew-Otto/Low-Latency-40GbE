// 64 bit one-cycle poly x^58 + x^39 + 1 descrambler
module descrambler (
  input  logic         clk,
  input  logic         reset,
  input  logic         bypass,
  input  logic [255:0] data_in,
  output logic [255:0] data_out
);

  logic [255:0] descrambled;
  logic [57:0] state, temp_state;

  assign data_out = bypass ? data_in : descrambled;

  always_ff @(posedge clk, posedge reset) begin
    if (reset)   state <= '0;
    else if (~bypass) state <= temp_state;
  end

  always_comb begin
    temp_state = state;
    for (int i = 0; i < 256; i = i + 1) begin
      descrambled[i] = data_in[i] ^ temp_state[57] ^ temp_state[38];
      temp_state = {temp_state[56:0], data_in[i]};
    end
  end

endmodule : descrambler
