derive_clock_uncertainty
create_clock -name refclk_qsfp1 -period 1.551515 [get_ports {refclk_qsfp1_p}]

set_clock_groups -asynchronous -group [get_clocks {core_pll_i|iopll_0_outclk0}] -group [get_clocks {phy_40g|tx_clkout|ch0 phy_40g|tx_clkout|ch1 phy_40g|tx_clkout|ch2 phy_40g|tx_clkout|ch3}]
set_clock_groups -asynchronous -group [get_clocks {core_pll_i|iopll_0_outclk0}] -group [get_clocks {phy_40g|rx_transfer_clk|ch0 phy_40g|rx_transfer_clk|ch1 phy_40g|rx_transfer_clk|ch2 phy_40g|rx_transfer_clk|ch3}]