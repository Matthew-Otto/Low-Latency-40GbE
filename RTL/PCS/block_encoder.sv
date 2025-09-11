// IEEE 802.3-2022 82.2.3.3
// 64B/66B block encoder
// translates bytes from MAC to 40/100GBASE-R code blocks


// first byte of first data block should be control (valid_bytes = 0xFE)
// first block that doesnt contain full valid_bytes will be marked as a \T\ (end) block

module block_encoder (
  input  logic        clk,
  input  logic        reset,
  input  logic        en,

  input  logic [63:0] data_in,
  input  logic [7:0]  valid_bytes,
  output logic [65:0] block_out
);

  enum {
    IDLE,
    START,
    DATA,
    END0,
    END1,
    END2,
    END3,
    END4,
    END5,
    END6,
    END7
  } code;

  logic data_state;

  always_comb begin
    case ({data_state, valid_bytes})
      9'b0_0000_0000 : code = IDLE;
      9'b0_1111_1110 : code = START;
      9'b1_1111_1111 : code = DATA;
      9'b1_0111_1111 : code = END7;
      9'b1_0011_1111 : code = END6;
      9'b1_0001_1111 : code = END5;
      9'b1_0000_1111 : code = END4;
      9'b1_0000_0111 : code = END3;
      9'b1_0000_0011 : code = END2;
      9'b1_0000_0001 : code = END1;
      9'b1_0000_0000 : code = END0;
      default      : code = IDLE;
    endcase
  end

  always_ff @(posedge clk, posedge reset) begin
    if (reset)
      data_state <= 0;
    else if (en)
      case (code)
        START : data_state <= 1;
        END7,
        END6,
        END5,
        END4,
        END3,
        END2,
        END1,
        END0 : data_state <= 0;
      endcase
  end

  always_comb begin
    case (code)
      IDLE  : block_out = {56'h0, 8'h78, 2'b01};
      START : block_out = {data_in[63:8], 8'h1E, 2'b01};
      DATA  : block_out = {data_in, 2'b10};
      END0  : block_out = {56'h0, 8'hE1, 2'b01};
      END1  : block_out = {48'h0, data_in[7:0], 8'h99, 2'b01};
      END2  : block_out = {40'h0, data_in[15:0], 8'h55, 2'b01};
      END3  : block_out = {32'h0, data_in[23:0], 8'h2D, 2'b01};
      END4  : block_out = {24'h0, data_in[31:0], 8'h33, 2'b01};
      END5  : block_out = {16'h0, data_in[39:0], 8'h4B, 2'b01};
      END6  : block_out = {8'h0,  data_in[47:0], 8'h87, 2'b01};
      END7  : block_out = {data_in[55:0], 8'hFF, 2'b01};
    endcase
  end


endmodule : block_encoder
