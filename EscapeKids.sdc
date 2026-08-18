# EscapeKids uses the JTFRAME compatibility wrapper, whose fitted main PLL
# hierarchy is different from the historical Template_MiSTer wildcard in
# sys/sys_top.sdc. Keep the original framework SDC untouched and add the
# exact fitted clock groups here. The game domains are all synchronous enables
# of the main 48 MHz PLL; these groups only separate independent framework
# PLLs and root clocks as intended by the Template contract.
derive_pll_clocks
derive_clock_uncertainty

set_clock_groups -exclusive \
    -group [get_clocks {emu|u_jtframe|pll|u_pll|*PLL_OUTPUT_COUNTER|divclk}] \
    -group [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter*output_counter|divclk}] \
    -group [get_clocks {pll_audio|pll_audio_inst|altera_pll_i|general*PLL_OUTPUT_COUNTER|divclk}] \
    -group [get_clocks {spi_sck}] \
    -group [get_clocks {hdmi_sck}] \
    -group [get_clocks {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}] \
    -group [get_clocks {FPGA_CLK1_50}] \
    -group [get_clocks {FPGA_CLK2_50}] \
    -group [get_clocks {FPGA_CLK3_50}]
