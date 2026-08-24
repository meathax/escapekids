# EscapeKids uses the JTFRAME compatibility wrapper, whose fitted main PLL
# hierarchy is different from the historical Template_MiSTer wildcard in
# sys/sys_top.sdc. Keep the original framework SDC untouched and add the
# exact fitted clock groups here. The game domains are all synchronous enables
# of the main 48 MHz PLL; these groups only separate independent framework
# PLLs and root clocks as intended by the Template contract.
derive_pll_clocks
derive_clock_uncertainty

# JOY_CLK is JCLOCKS[3] in the active DB15 divider: 48 MHz / 16 = 3 MHz.
# Target the fitted register as a keeper; a bare register name is not a pin.
set joy_db15_source [get_pins {emu|u_jtframe|pll|u_pll|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set joy_db15_target [get_keepers {emu:emu|escape_kids_jtframe_emu:u_jtframe|jtframe_mister:u_frame|jtframe_joymux:u_joymux|joy_db15:u_db15|JCLOCKS[3]}]
if { [get_collection_size $joy_db15_source] != 1 } {
    error "Expected exactly one JTFRAME DB15 serializer source clock pin"
}
if { [get_collection_size $joy_db15_target] != 1 } {
    error "Expected exactly one JTFRAME DB15 serializer JCLOCKS[3] keeper"
}
create_generated_clock -name joy_db15_clk -source $joy_db15_source -divide_by 16 $joy_db15_target

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
