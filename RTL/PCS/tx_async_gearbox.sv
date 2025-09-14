// async gearbox
// accepts 66 bits at 156.25 MHz and outputs 32 bits at 322.2656225 MHz
// If either clock deviates AT ALL, the buffer will eventually overflow/underrun

module tx_async_gearbox (
  input  logic        clk_in,
  input  logic        clk_in_reset,
  input  logic        clk_out,
  input  logic        clk_out_reset,

  // clk_in domain
  input  logic [65:0] data_in,
  input  logic        valid_in,

  // clk_out domain
  output logic [31:0] data_out,
  output logic        valid_out
);

  localparam BUFFER_SIZE = 4;
  localparam PTR_SIZE = $clog2(BUFFER_SIZE);
  localparam BIT_PTR_SIZE = $clog2(BUFFER_SIZE<<7);
  localparam ROLL_OVER = BUFFER_SIZE * 66;

  logic empty;
  logic wr_en;

  (* ramstyle = "logic" *) logic [65:0] buffer [BUFFER_SIZE-1:0];

  // input clk domain
  logic [PTR_SIZE-1:0] wr_ptr, next_wr_ptr;
  logic [PTR_SIZE-1:0] wr_ptr_g;
  // output clk domain
  logic [BIT_PTR_SIZE-1:0] rd_b_ptr, next_rd_b_ptr, raw_next_rd_b_ptr;
  logic [PTR_SIZE-1:0] wr_ptr_g_sync1, wr_ptr_g_sync2;
  logic [PTR_SIZE-1:0] wr_ptr_sync;
  logic [PTR_SIZE-1:0] rd_ptr, next_rd_ptr;
  logic [6:0] row_sel, next_row_sel;
  logic [131:0] read_row;


  ///////////////////////////////////////
  ////// write (clk_in) domain //////////
  ///////////////////////////////////////
  
  assign wr_en = valid_in && ~clk_in_reset;

  assign next_wr_ptr = wr_ptr + 1;
  
  always_ff @(posedge clk_in or posedge clk_in_reset) begin
    if (clk_in_reset) begin
      wr_ptr <= 0;
      wr_ptr_g <= 0;
    end else if (valid_in) begin
      wr_ptr <= next_wr_ptr;
      wr_ptr_g <= next_wr_ptr ^ (next_wr_ptr >> 1);
    end
  end
  
  always_ff @(posedge clk_in) begin
    if (wr_en)
    buffer[wr_ptr] <= data_in;
  end
  
  
  ///////////////////////////////////////
  ////// read (clk_out) domain //////////
  ///////////////////////////////////////

  assign empty = (rd_ptr == wr_ptr_sync);

  assign raw_next_rd_b_ptr = rd_b_ptr + 32;
  assign next_rd_b_ptr = (raw_next_rd_b_ptr >= ROLL_OVER) ? (raw_next_rd_b_ptr - ROLL_OVER) : raw_next_rd_b_ptr;

  assign next_rd_ptr = next_rd_b_ptr / 66;
  assign next_row_sel = next_rd_b_ptr % 66;

  always_ff @(posedge clk_out or posedge clk_out_reset) begin
    if (clk_out_reset) begin
      rd_b_ptr <= 0;
      rd_ptr <= 0;
      row_sel <= 0;
    end else if (~empty) begin
      rd_b_ptr <= next_rd_b_ptr;
      rd_ptr <= next_rd_ptr;
      row_sel <= next_row_sel;
    end
  end

  // cross clocks
  always_ff @(posedge clk_out or posedge clk_out_reset) begin
    if (clk_out_reset) {wr_ptr_g_sync2, wr_ptr_g_sync1} <= 0;
    else               {wr_ptr_g_sync2, wr_ptr_g_sync1} <= {wr_ptr_g_sync1, wr_ptr_g};
  end
  // convert gray code back to binary
  always_comb begin
    for (int i = 0; i < PTR_SIZE; i++)
      wr_ptr_sync[i] = ^(wr_ptr_g_sync2 >> i);
  end

  // select 32 bits from 66 bit rows
  always_comb begin
    read_row = {buffer[rd_ptr+1],buffer[rd_ptr]};
    //data_out = read_row[row_sel+:32];
  end

  always_ff @(posedge clk_out) begin
    data_out <= read_row[row_sel+:32];
    valid_out <= ~empty;
  end

endmodule : tx_async_gearbox
