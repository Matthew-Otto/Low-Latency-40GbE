// 64 bit one-cycle poly x^58 + x^39 + 1 scrambler
module scrambler (
  input  logic        clk,
  input  logic        reset,
  input  logic        en,
  input  logic [63:0] data_in,
  output logic [63:0] data_out
);

  logic [57:0] state, temp_state;

  always_ff @(posedge clk, posedge reset) begin
    if (reset)   state <= '0;
    else if (en) state <= temp_state;
      /* for (int i = 0; i < 58; i++)
        state[i] <= data_out[63-i]; */
  end

  always_comb begin
    /* for (int i = 0; i < 64; i++) begin
      if (i <= 38)
        data_out[i] = data_in[i] ^ state[38-i] ^ state[57-i];
      else if (i <= 57)
        data_out[i] = data_in[i] ^ data_out[(38-i+1)*-1] ^ state[57-i];
      else
        data_out[i] = data_in[i] ^ data_out[(38-i+1)*-1] ^ data_out[(57-i+1)*-1];
    end */
    temp_state = state;
    for (int i = 0; i < 64; i = i + 1) begin
      data_out[i] = data_in[i] ^ temp_state[57] ^ temp_state[38];
      temp_state = {temp_state[56:0], data_out[i]};
    end
  end

endmodule : scrambler
