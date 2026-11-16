# All internal sequential logic runs on CLOCK_50; pixel clock is output-only.
create_clock -name sys_clk -period 20.000 [get_ports {CLOCK_50}]
# Quartus 13 merges video|phase with the identical cycle-counter low bit.
# Declare the divider at its register, then forward it to the DAC clock pin.
# Accept the unmerged name too; fail rather than silently lose this constraint.
set pixel_divider [get_registers -nowarn {*|video|phase *|cycles[0]}]
if {[get_collection_size $pixel_divider] != 1} {
 error "Expected exactly one VGA divide-by-two register"
}
create_generated_clock -name pixel_div -source [get_ports {CLOCK_50}] -divide_by 2 $pixel_divider
create_generated_clock -name dac_clk -source $pixel_divider -divide_by 1 [get_ports {VGA_CLK}]
set_clock_uncertainty -from [get_clocks {sys_clk pixel_div dac_clk}] -to [get_clocks {sys_clk pixel_div dac_clk}] 0.200
# Conservative 5 ns setup and 2 ns hold budget, including provisional PCB skew.
# Must be reviewed against the fitted DAC variant and board timing before release.
set dac_data [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_BLANK VGA_SYNC VGA_HS VGA_VS}]
set_output_delay -clock dac_clk -max 5.000 $dac_data
set_output_delay -clock dac_clk -min -2.000 $dac_data
# Only asynchronous input -> first synchronizer stage is excepted.
set_false_path -from [get_ports {PS2_CLK}] -to [get_registers {*|clock_sync[0]}]
set_false_path -from [get_ports {PS2_DAT}] -to [get_registers {*|data_sync[0]}]
# Pushbutton asynchronously asserts the reset-release chain only.
set_false_path -from [get_ports {KEY[0]}] -to [get_registers {reset_pipe[*]}]
# Static diagnostic LED has no external sampling clock.
set_false_path -to [get_ports {LEDR[0]}]
# No blanket internal false paths or multicycle timing relaxations.
