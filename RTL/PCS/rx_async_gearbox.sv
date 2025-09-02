// async gearbox
// accepts 32 bits at 322.2656225 MHz and outputs 66 bits at 156.25 MHz
// If either clock deviates AT ALL, the buffer will eventually overflow/underrun

module rx_async_gearbox (
  input  logic        clk_in,
  input  logic        clk_in_reset,
  input  logic        clk_out,
  input  logic        clk_out_reset,

  // clk_in domain
  input  logic [31:0] data_in,
  input  logic        valid_in,

  // clk_out domain
  input  logic        bitslip,
  output logic [65:0] data_out,
  output logic        valid_out
);

  localparam BUFFER_SIZE = 16;
  localparam ADDR_SIZE = $clog2(BUFFER_SIZE);
  localparam PTR_SIZE = $clog2(BUFFER_SIZE<<5);

  logic empty;
  logic wr_en;
  logic [4:0]   sel_addr;
  logic [127:0] read_row;
  logic [65:0]  data_out_sel;

  logic [31:0] buffer [BUFFER_SIZE-1:0];
  logic [PTR_SIZE-1:0]  w_ptr_b, next_w_ptr_b;
  logic [ADDR_SIZE-1:0] w_addr_g;

  logic [ADDR_SIZE-1:0] r_ptr_addr;
  logic [PTR_SIZE-1:0]  r_ptr_b, next_r_ptr_b;
  logic [PTR_SIZE-1:0]  r_ptr_g;
  logic [ADDR_SIZE-1:0] w_addr_g_sync2, w_addr_g_sync1;
  logic [ADDR_SIZE-1:0] w_addr_b_sync;
  logic [PTR_SIZE-1:0]  w_ptr_b_sync;


  //// write (clk_in) domain
  // TODO: FULL
  assign next_w_ptr_b = w_ptr_b + 32;
  //assign next_w_addr_g = next_w_ptr_b ^ (next_w_ptr_b >> 1);
  assign wr_en = valid_in && ~clk_in_reset;

  always_ff @(posedge clk_in or posedge clk_in_reset) begin
    if (clk_in_reset) begin
      w_ptr_b <= 0;
      w_addr_g <= 0;
    end else if (valid_in) begin
      w_ptr_b <= next_w_ptr_b;
      w_addr_g <= (next_w_ptr_b >> 5) ^ (next_w_ptr_b >> 6);
    end
  end

  always_ff @(posedge clk_in) begin
    if (wr_en)
      buffer[w_ptr_b>>5] <= data_in;
  end



  //// read (clk_out) domain
  assign next_r_ptr_b = bitslip ? r_ptr_b + 67 : r_ptr_b + 66;
  assign empty = (next_r_ptr_b > w_ptr_b_sync) && (r_ptr_b <= w_ptr_b_sync);

  always_ff @(posedge clk_out or posedge clk_out_reset) begin
    if (clk_out_reset) begin
      r_ptr_b <= 0;
      r_ptr_g <= 0;
    end else if (~empty && ~clk_out_reset) begin
      r_ptr_b <= next_r_ptr_b;
      r_ptr_g <= next_r_ptr_b ^ (next_r_ptr_b >> 1);
    end
  end

  always_ff @(posedge clk_out or posedge clk_out_reset) begin
    if (clk_out_reset) {w_addr_g_sync2, w_addr_g_sync1} <= 0;
    else           {w_addr_g_sync2, w_addr_g_sync1} <= {w_addr_g_sync1, w_addr_g};
  end

  always_comb begin
    for (int i = 0; i < ADDR_SIZE; i++)
      w_addr_b_sync[i] = ^(w_addr_g_sync2 >> i);
    w_ptr_b_sync = w_addr_b_sync << 5;
    
    r_ptr_addr = r_ptr_b>>5;
    sel_addr = bitslip ? (r_ptr_b & 5'h1F) + 1 : (r_ptr_b & 5'h1F);
    read_row = {buffer[r_ptr_addr+3],buffer[r_ptr_addr+2],buffer[r_ptr_addr+1],buffer[r_ptr_addr]};
    data_out_sel = read_row[sel_addr+:66];
  end

  always_ff @(posedge clk_out) begin
    data_out <= data_out_sel;
    valid_out <= ~empty && ~clk_out_reset;
  end
  

endmodule : rx_async_gearbox
