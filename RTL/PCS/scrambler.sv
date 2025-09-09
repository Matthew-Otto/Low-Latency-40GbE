// 256 bit one-cycle poly x^58 + x^39 + 1 scrambler
module scrambler (
  input  logic        clk,
  input  logic        reset,
  input  logic        en,
  input  logic [255:0] data_in,
  output logic [255:0] data_out
);

  logic [57:0] state, temp_state;

  always_ff @(posedge clk, posedge reset) begin
    if (reset)   state <= '0;
    else if (en) state <= temp_state;
  end

  always_comb begin
    temp_state = state;
    for (int i = 0; i < 256; i = i + 1) begin
      data_out[i] = data_in[i] ^ temp_state[57] ^ temp_state[38];
      temp_state = {temp_state[56:0], data_out[i]};
    end
  end

endmodule : scrambler
