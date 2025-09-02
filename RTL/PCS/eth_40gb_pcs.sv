module eth_40gb_pcs (
  input  logic         core_clk,
  input  logic         core_reset,

  input  logic [3:0]   rx_phy_clk,
  input  logic [127:0] rx_parallel_data,
  
  output logic [127:0] tx_parallel_data
);
  
  genvar i;

  typedef enum logic [7:0] {
    C_IDLE = 8'h07,
    C_SOF = 8'hFB, // start of frame K27.7
    C_EOF = 8'hFD, // end of frame K29.7
    C_K28_0 = 8'h1C,
    C_K28_1 = 8'h3C,
    C_K28_2 = 8'h5C,
    C_K28_3 = 8'h7C,
    C_K28_4 = 8'h9C,
    C_K28_5 = 8'hBC,
    C_K28_6 = 8'hDC,
    C_K28_7 = 8'hFC
  } ctrl_codes;
  
  //// RX
  logic [3:0] bitslip;
  logic [3:0] block_locked;
  logic [65:0] rx_scrambled [3:0];
  (* preserve_for_debug *) logic [65:0] rx_descrambled [3:0];

  generate
    for (i = 0; i < 4; i++) begin
      rx_async_gearbox rx_async_gearbox_i (
        .clk_in(rx_phy_clk[i]),
        .clk_in_reset(),
        .clk_out(core_clk),
        .clk_out_reset(core_reset),
        .data_in(rx_parallel_data[i*32+:32]),
        .valid_in(1'b1),
        .bitslip(bitslip[i]),
        .data_out(rx_scrambled[i]),
        .valid_out()
      );

      block_sync block_sync_i (
        .clk(core_clk),
        .reset(core_reset),
        .sync_bits(rx_scrambled[i][1:0]),
        .bitslip(bitslip[i]),
        .block_locked(block_locked[i])
      );

      descrambler descrambler_i (
        .clk(core_clk),
        .reset(core_reset),
        .en(block_locked[i]),
        .data_in(rx_scrambled[i][65:2]), // BOZO might need to reverse block bit-order
        .data_out(rx_descrambled[i][65:2])
      );
      assign rx_descrambled[i][1:0] = rx_scrambled[i][1:0];

    end
  endgenerate






endmodule : eth_40gb_pcs
