module eth_40gb_mac (
  input  logic core_clk,
  input  logic core_reset,

  input  logic [3:0]   rx_phy_clk,
  input  logic [127:0] rx_parallel_data,

  output logic [127:0] tx_parallel_data,
);
  

endmodule : eth_40gb_mac
