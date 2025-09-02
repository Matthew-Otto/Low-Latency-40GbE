
module block_sync (
  input  logic       clk,
  input  logic       reset,
  input  logic [1:0] sync_bits,
  output logic       bitslip,
  output logic       block_locked
);

  logic        clear_history;
  logic [63:0] history;
  logic [6:0]  sync_cnt, next_sync_cnt;
  logic [6:0]  error_cnt;

  enum {
    LOS,
    SYNC,
    LOCKED
  } state, next_state;

  always_ff @(posedge clk, posedge reset) begin
    if (reset) state <= LOS;
    else       state <= next_state;
    
    if (reset) sync_cnt <= 0;
    else       sync_cnt <= next_sync_cnt;
  end

  always_comb begin
    next_state = state;
    next_sync_cnt = 0;
    clear_history = 0;
    bitslip = 0;
    block_locked = 0;

    case (state)
      LOS : begin
        if (^sync_bits) begin
          clear_history = 1;
          next_state = SYNC;
        end else begin
          bitslip = 1;
        end
      end

      SYNC : begin
        next_sync_cnt = sync_cnt + 1;

        if (error_cnt[1])
          next_state = LOS;
        else if (sync_cnt[6])
          next_state = LOCKED;
      end

      LOCKED : begin
        if (error_cnt[4])
          next_state = LOS;
      end
    endcase
  end


  always_ff @(posedge clk, posedge reset) begin
    if (reset || clear_history) begin
      history <= '1;
      error_cnt <= 0;
    end else begin
      history[0] <= ^sync_bits;
      for (int i = 1; i < 64; i++)
        history[i] <= history[i-1];

      case ({history[63],^sync_bits})
        2'b10: error_cnt <= error_cnt + 1;
        2'b01: error_cnt <= error_cnt - 1;
        default;
      endcase
    end
  end

endmodule : block_sync
