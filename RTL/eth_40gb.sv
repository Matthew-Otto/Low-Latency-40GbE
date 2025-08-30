module eth_40gb (
  input logic         clk_fpga_50m,
  input logic         cpu_resetn,

  //Transceiver Reference Clock
  input logic         refclk_qsfp1_p,     //LVDS - 644.53125MHz

  //QSFP
  input  logic [3:0]  qsfp1_rx_p,         //QSFP XCVR RX Data
  output logic [3:0]  qsfp1_tx_p,         //QSFP XCVR TX Data
  input  logic        qsfp1_interruptn,
  output logic        qsfp1_lp_mode,
  input  logic        qsfp1_mod_prsn,
  output logic        qsfp1_mod_seln,
  output logic        qsfp1_rstn,
  output logic        qsfp1_scl,
  inout  logic        qsfp1_sda
);

  // clocks
  logic core_clk;
  logic serial_clk;
  logic rx_clk;
  logic core_pll_locked;

  // resets
  logic init_reset_async;
  logic init_reset;
  logic reset_master;
  logic [3:0] tx_analog_reset;
  logic [3:0] tx_digital_reset;
  logic [3:0] rx_analog_reset;
  logic [3:0] rx_digital_reset;

  // qsfp pll status
  logic tx_pll_locked;
  logic tx_pll_cal_busy;
  logic [3:0] tx_cal_busy;
  logic [3:0] rx_cal_busy;
  logic [3:0] rx_is_lockedtodata;
  logic [3:0] tx_ready;
  logic [3:0] rx_ready;
  logic [3:0] tx_analogreset_stat;
  logic [3:0] tx_digitalreset_stat;
  logic [3:0] rx_analogreset_stat;
  logic [3:0] rx_digitalreset_stat;

  // PMA
  logic [255:0] rx_parallel_data;
  logic [63:0] rx_data_channel [3:0];

  reset_release reset_release_i (
    .ninit_done (init_reset_async)
  );

  reset_sync reset_sync_i (
    .clk(core_clk),
    .async_reset(init_reset_async | ~core_pll_locked),
    .sync_reset(init_reset)
  );

  assign reset_master = init_reset || ~cpu_resetn;


  //// QSFP reset
  phy_reset phy_reset_i (
    .clock                (core_clk),             //   input,  width = 1,                clock.clk
    .reset                (reset_master),         //   input,  width = 1,                reset.reset
    .tx_analogreset       (tx_analog_reset),      //  output,  width = 4,       tx_analogreset.tx_analogreset
    .tx_digitalreset      (tx_digital_reset),     //  output,  width = 4,      tx_digitalreset.tx_digitalreset
    .tx_ready             (tx_ready),             //  output,  width = 4,             tx_ready.tx_ready
    .pll_locked           (tx_pll_locked),        //   input,  width = 1,           pll_locked.pll_locked
    .pll_cal_busy         (tx_pll_cal_busy),      //   input,  width = 1,         pll_cal_busy.pll_cal_busy
    .pll_select           (1'b0),                    //   input,  width = 1,           pll_select.pll_select
    .tx_cal_busy          (tx_cal_busy),          //   input,  width = 4,          tx_cal_busy.tx_cal_busy
    .rx_analogreset       (rx_analog_reset),      //  output,  width = 4,       rx_analogreset.rx_analogreset
    .rx_digitalreset      (rx_digital_reset),     //  output,  width = 4,      rx_digitalreset.rx_digitalreset
    .rx_ready             (rx_ready),             //  output,  width = 4,             rx_ready.rx_ready
    .rx_is_lockedtodata   (rx_is_lockedtodata),   //   input,  width = 4,   rx_is_lockedtodata.rx_is_lockedtodata
    .rx_cal_busy          (rx_cal_busy),          //   input,  width = 4,          rx_cal_busy.rx_cal_busy
    .tx_analogreset_stat  (tx_analogreset_stat),  //   input,  width = 4,  tx_analogreset_stat.tx_analogreset_stat
    .tx_digitalreset_stat (tx_digitalreset_stat), //   input,  width = 4, tx_digitalreset_stat.tx_digitalreset_stat
    .rx_analogreset_stat  (rx_analogreset_stat),  //   input,  width = 4,  rx_analogreset_stat.rx_analogreset_stat
    .rx_digitalreset_stat (rx_digitalreset_stat)  //   input,  width = 4, rx_digitalreset_stat.rx_digitalreset_stat
  );


  //// Core PLL
  core_pll core_pll_i (
    .refclk   (clk_fpga_50m),      //   input,  width = 1,  refclk.clk
    .rst      (init_reset_async),  //   input,  width = 1,   reset.reset
    .locked   (core_pll_locked),   //  output,  width = 1,  locked.export
    .outclk_0 (core_clk)           //  output,  width = 1, outclk0.clk
  );

  //// QSFP PLL
  qsfp_atx_pll tx_pll (
    .pll_refclk0   (refclk_qsfp1_p),   //   input,  width = 1,   pll_refclk0.clk
    .tx_serial_clk (serial_clk),       //  output,  width = 1, tx_serial_clk.clk
    .pll_locked    (tx_pll_locked),    //  output,  width = 1,    pll_locked.pll_locked
    .pll_cal_busy  (tx_pll_cal_busy)   //  output,  width = 1,  pll_cal_busy.pll_cal_busy
  );


  //// QSFP PMA
  pma_40gbe_serdes serdes (
    .tx_analogreset          (tx_analog_reset),          //   input,    width = 4,          tx_analogreset.tx_analogreset
    .rx_analogreset          (rx_analog_reset),          //   input,    width = 4,          rx_analogreset.rx_analogreset
    .tx_digitalreset         (tx_digital_reset),         //   input,    width = 4,         tx_digitalreset.tx_digitalreset
    .rx_digitalreset         (rx_digital_reset),         //   input,    width = 4,         rx_digitalreset.rx_digitalreset
    .tx_analogreset_stat     (tx_analogreset_stat),     //  output,    width = 4,     tx_analogreset_stat.tx_analogreset_stat
    .rx_analogreset_stat     (tx_digitalreset_stat),     //  output,    width = 4,     rx_analogreset_stat.rx_analogreset_stat
    .tx_digitalreset_stat    (rx_analogreset_stat),    //  output,    width = 4,    tx_digitalreset_stat.tx_digitalreset_stat
    .rx_digitalreset_stat    (rx_digitalreset_stat),    //  output,    width = 4,    rx_digitalreset_stat.rx_digitalreset_stat
    .tx_cal_busy             (tx_cal_busy),             //  output,    width = 4,             tx_cal_busy.tx_cal_busy
    .rx_cal_busy             (rx_cal_busy),             //  output,    width = 4,             rx_cal_busy.rx_cal_busy
    .tx_serial_clk0          ({4{serial_clk}}),          //   input,    width = 4,          tx_serial_clk0.clk
    .rx_cdr_refclk0          (serial_clk),          //   input,    width = 1,          rx_cdr_refclk0.clk
    .tx_serial_data          (qsfp1_tx_p),          //  output,    width = 4,          tx_serial_data.tx_serial_data
    .rx_serial_data          (qsfp1_rx_p),          //   input,    width = 4,          rx_serial_data.rx_serial_data
    .rx_is_lockedtoref       (),       //  output,    width = 4,       rx_is_lockedtoref.rx_is_lockedtoref
    .rx_is_lockedtodata      (rx_is_lockedtodata),      //  output,    width = 4,      rx_is_lockedtodata.rx_is_lockedtodata
    .tx_coreclkin            (),            //   input,    width = 4,            tx_coreclkin.clk
    .rx_coreclkin            ({4{core_clk}}),            //   input,    width = 4,            rx_coreclkin.clk
    .tx_clkout               (),               //  output,    width = 4,               tx_clkout.clk
    .tx_clkout2              (),              //  output,    width = 4,              tx_clkout2.clk
    .rx_clkout               (),               //  output,    width = 4,               rx_clkout.clk
    .rx_clkout2              (),              //  output,    width = 4,              rx_clkout2.clk
    .tx_parallel_data        (),        //   input,  width = 256,        tx_parallel_data.tx_parallel_data
    .tx_control              (),              //   input,   width = 32,              tx_control.tx_control
    .tx_err_ins              (),              //   input,    width = 4,              tx_err_ins.tx_err_ins
    .tx_enh_data_valid       (),       //   input,    width = 4,       tx_enh_data_valid.tx_enh_data_valid
    .rx_parallel_data        (rx_parallel_data),        //  output,  width = 256,        rx_parallel_data.rx_parallel_data
    .rx_control              (),              //  output,   width = 32,              rx_control.rx_control
    .rx_enh_data_valid       (),       //  output,    width = 4,       rx_enh_data_valid.rx_enh_data_valid
    .tx_fifo_full            (),            //  output,    width = 4,            tx_fifo_full.tx_fifo_full
    .tx_fifo_empty           (),           //  output,    width = 4,           tx_fifo_empty.tx_fifo_empty
    .tx_fifo_pfull           (),           //  output,    width = 4,           tx_fifo_pfull.tx_fifo_pfull
    .tx_fifo_pempty          (),          //  output,    width = 4,          tx_fifo_pempty.tx_fifo_pempty
    .rx_fifo_full            (),            //  output,    width = 4,            rx_fifo_full.rx_fifo_full
    .rx_fifo_empty           (),           //  output,    width = 4,           rx_fifo_empty.rx_fifo_empty
    .rx_fifo_insert          (),          //  output,    width = 4,          rx_fifo_insert.rx_fifo_insert
    .rx_fifo_del             (),             //  output,    width = 4,             rx_fifo_del.rx_fifo_del
    .rx_enh_highber          (),          //  output,    width = 4,          rx_enh_highber.rx_enh_highber
    .rx_enh_blk_lock         (),          //  output,    width = 4,         rx_enh_blk_lock.rx_enh_blk_lock
    .unused_tx_parallel_data (), //   input,   width = 24, unused_tx_parallel_data.unused_tx_parallel_data
    .unused_rx_parallel_data () //  output,   width = 28, unused_rx_parallel_data.unused_rx_parallel_data
  );


  always_comb begin
    for (int i = 0; i < 4; i++)
      rx_data_channel[i] = rx_parallel_data[i*64+:64];
  end

endmodule : eth_40gb
