module eth_40gb_pcs (
  input  logic         core_clk,
  input  logic         core_reset,

  // MAC interface
  output logic         tx_data_ready,
  input  logic         tx_data_valid,
  input  logic [255:0] tx_data,

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

      alignment_extractor #(
        .LANE_NUMBER(i)
      ) alignment_extractor_1 (
        .clk(core_clk),
        .reset(core_reset),
        .block_in(rx_scrambled[i]),
        .marker_detect(marker_detect[i]),
        .bip_valid(bip_valid[i])
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


  ////////////////////////////////////////////////////////////////////
  //// TX ////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////

  logic         scrambler_en;
  logic         jam_alignment_marker;
  logic [3:0]   jam_next_cycle;
  logic [255:0] tx_scrambler_in;
  logic [255:0] tx_scrambler_out;
  logic [65:0]  tx_scrambled_block [3:0];
  logic [65:0]  tx_alignment_marker [3:0];
  logic [65:0]  tx_lane [3:0];

  enum logic [1:0] {
    S_CTRL = 2'b01,
    S_DATA = 2'b10
  } sync_header;

  enum {
    TX_STALL_IDLE,
    TX_IDLE,
    TX_STALL_DATA,
    TX_DATA
  } tx_state, next_tx_state;

  always_ff @(posedge core_clk or posedge core_reset) begin
    if (core_reset) tx_state <= TX_STALL_IDLE;
    else            tx_state <= next_tx_state;
  end

  // BOZO: can remove a cycle of latency by not waiting to assert ready
  // may not need this state machine at all
  always_comb begin
    next_tx_state = tx_state;
    tx_data_ready = 0;
    scrambler_en = 0;
    jam_alignment_marker = 0;
    
    case (tx_state)
      TX_STALL_IDLE : begin
        jam_alignment_marker = 1;
        next_tx_state = TX_IDLE;
      end

      TX_IDLE : begin
        scrambler_en = 1;
        sync_header = S_CTRL;
        tx_scrambler_in = {4{56'h0, 8'h78}};

        if (jam_next_cycle[0])
          next_tx_state = TX_STALL_IDLE;
        else if (tx_data_valid)
          next_tx_state = TX_DATA;
      end

      TX_STALL_DATA : begin
        jam_alignment_marker = 1;
        next_tx_state = TX_DATA;
      end

      TX_DATA : begin
        scrambler_en = 1;
        tx_data_ready = 1;
        sync_header = S_DATA;
        tx_scrambler_in = tx_data;

        if (jam_next_cycle[0])
          next_tx_state = TX_STALL_DATA;
        // if no data goto idle
      end
    endcase
  end

  scrambler scrambler_i (
    .clk(core_clk),
    .reset(core_reset),
    .en(scrambler_en),
    .data_in(tx_scrambler_in),
    .data_out(tx_scrambler_out)
  );

  generate
    for (i = 0; i < 4; i++) begin : block_distribution
      assign tx_scrambled_block[i] = {tx_scrambler_out[i*64+:64], sync_header};

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
