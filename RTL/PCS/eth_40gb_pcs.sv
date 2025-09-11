module eth_40gb_pcs (
  input  logic         core_clk,
  input  logic         core_reset,

  // MAC interface
  input  logic [255:0] tx_data,
  input  logic [31:0]  tx_data_valid,
  input  logic         tx_data_ready,

  // Serial interface
  input  logic [3:0]   rx_phy_clk,
  input  logic [127:0] rx_parallel_data,
  
  input  logic [3:0]   tx_phy_clk,
  output logic [127:0] tx_parallel_data
);
  
  genvar i, j;

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
  

  ////////////////////////////////////////////////////////////////////
  //// RX ////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////
  logic [3:0] bitslip;
  logic [3:0] marker_detect;
  logic [3:0] bip_valid;
  (* preserve_for_debug *) logic [3:0] block_locked;
  logic [65:0] rx_scrambled [3:0];
  logic [255:0] rx_descrambled;
  logic [65:0] rx_encoded [3:0];

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

      alignment_extractor #(
        .LANE_NUMBER(i)
      ) alignment_extractor_1 (
        .clk(core_clk),
        .reset(core_reset),
        .block_in(rx_scrambled[i]),
        .marker_detect(marker_detect[i]),
        .bip_valid(bip_valid[i])
      );

    end
  endgenerate

  descrambler descrambler_i (
    .clk(core_clk),
    .reset(core_reset),
    .bypass(|marker_detect),
    .data_in({rx_scrambled[3][65:2],rx_scrambled[2][65:2],rx_scrambled[1][65:2],rx_scrambled[0][65:2]}),
    .data_out(rx_descrambled)
  );

  always_comb begin
    for (int k = 0; k < 4; k++)
      rx_encoded[k] = {rx_descrambled[k*64+:64],rx_scrambled[k][1:0]};
  end


  ////////////////////////////////////////////////////////////////////
  //// TX ////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////

  logic         jam_alignment_marker;
  logic [3:0]   jam_next_cycle;
  logic [65:0]  tx_encoded_block [3:0];
  logic [255:0] tx_encoded_block4;
  logic [255:0] tx_scrambler_out;
  logic [65:0]  tx_scrambled_block [3:0];
  logic [65:0]  tx_alignment_marker [3:0];
  logic [65:0]  tx_lane [3:0];

  always_ff @(posedge core_clk)
    jam_alignment_marker <= jam_next_cycle[0];

  generate
    for (i = 0; i < 4; i++) begin : block_encoding
      block_encoder block_encoder_i (
        .clk(core_clk),
        .reset(core_reset),
        .en(~jam_alignment_marker),
        .data_in(tx_data[i*64+:64]),
        .valid_bytes(tx_data_valid[i*8+:8]),
        .block_out(tx_encoded_block[i])
      );
    end
  endgenerate
  
  assign tx_encoded_block4 = {tx_encoded_block[3][65:2],tx_encoded_block[2][65:2],tx_encoded_block[1][65:2],tx_encoded_block[0][65:2]};

  scrambler scrambler_i (
    .clk(core_clk),
    .reset(core_reset),
    .en(~jam_alignment_marker),
    .data_in(tx_encoded_block4),
    .data_out(tx_scrambler_out)
  );

  generate
    for (i = 0; i < 4; i++) begin : block_distribution
      assign tx_scrambled_block[i] = {tx_scrambler_out[i*64+:64], tx_encoded_block[i][1:0]};

      alignment_generator #(
        .LANE_NUMBER(i)
      ) alignment_generator_i (
        .clk(core_clk),
        .reset(core_reset),
        .block_in(tx_scrambled_block[i]),
        .marker_out(tx_alignment_marker[i]),
        .jam_next_cycle(jam_next_cycle[i])
      );

      assign tx_lane[i] = jam_alignment_marker ? tx_alignment_marker[i] : tx_scrambled_block[i];

      tx_async_gearbox tx_async_gearbox_i (
        .clk_in(core_clk),
        .clk_in_reset(core_reset),
        .clk_out(tx_phy_clk[i]),
        .clk_out_reset(),
        .data_in(tx_lane[i]),
        .valid_in(1),
        .data_out(tx_parallel_data[i*32+:32]),
        .valid_out()
      );

    end
  endgenerate

endmodule : eth_40gb_pcs
