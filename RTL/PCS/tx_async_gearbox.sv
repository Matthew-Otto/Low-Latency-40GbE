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

  localparam BUFFER_SIZE = 16;
  localparam PTR_SIZE = $clog2(BUFFER_SIZE);
  localparam ADDR_SIZE = $clog2(BUFFER_SIZE<<7);

  logic [31:0] buffer [BUFFER_SIZE-1:0];
  logic [31:0] buffer_wr [BUFFER_SIZE-1:0];

  logic empty;
  logic wr_en;
  
  logic [ADDR_SIZE-1:0] wr_addr, next_wr_addr, raw_next_wr_addr;
  logic [PTR_SIZE-1:0] wr_ptr_est;
  logic [PTR_SIZE-1:0] wr_ptr_g;
  logic [PTR_SIZE-1:0] wr_ptr_g_sync1, wr_ptr_g_sync2;
  
  logic [PTR_SIZE-1:0] wr_ptr_sync;
  logic [PTR_SIZE-1:0] rd_ptr, next_rd_ptr;


  //// write (clk_in) domain
  assign raw_next_wr_addr = wr_addr + 66;
  assign next_wr_addr = (raw_next_wr_addr > (BUFFER_SIZE*32)) ? (raw_next_wr_addr - (BUFFER_SIZE*32)) : raw_next_wr_addr;
  assign wr_ptr_est = next_wr_addr >> 5;
  
  assign wr_en = valid_in && ~clk_in_reset;


  always_ff @(posedge clk_in or posedge clk_in_reset) begin
    if (clk_in_reset) begin
      wr_addr <= 0;
      wr_ptr_g <= 0;
    end else if (valid_in) begin
      wr_addr <= next_wr_addr;
      wr_ptr_g <= wr_ptr_est ^ (wr_ptr_est >> 1);
    end
  end

  always_comb begin
    for (int i = 0; i < BUFFER_SIZE; i++)
      buffer_wr[i] = buffer[i];

    for (int i = 0; i < 66; i++)
      buffer_wr[(wr_addr+i)/32][(wr_addr+i)%32] = data_in[i];
  end

  always_ff @(posedge clk_in) begin
    if (wr_en)
      for (int i = 0; i < BUFFER_SIZE; i++)
        buffer[i] <= buffer_wr[i];
  end



  //// read (clk_out) domain
  assign next_rd_ptr = rd_ptr + 1;
  assign empty = rd_ptr == wr_ptr_sync;

  always_ff @(posedge clk_out or posedge clk_out_reset) begin
    if (clk_out_reset) begin
      rd_ptr <= 0;
    end else if (~empty) begin
      rd_ptr <= next_rd_ptr;
    end
  end

  // cross clocks
  always_ff @(posedge clk_out or posedge clk_out_reset) begin
    if (clk_out_reset) {wr_ptr_g_sync2, wr_ptr_g_sync1} <= 0;
    else               {wr_ptr_g_sync2, wr_ptr_g_sync1} <= {wr_ptr_g_sync1, wr_ptr_g};
  end
  always_comb begin
    for (int i = 0; i < PTR_SIZE; i++)
      wr_ptr_sync[i] = ^(wr_ptr_g_sync2 >> i);
  end

  always_ff @(posedge clk_out) begin
    data_out <= buffer[rd_ptr];
    valid_out <= ~empty;
  end

endmodule : tx_async_gearbox
