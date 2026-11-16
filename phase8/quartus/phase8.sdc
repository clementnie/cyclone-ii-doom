create_clock -name osc -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks

# Generated forwarded clock: SDRAM samples 8 ns after controller launch.
create_generated_clock -name sdram_pin -source [get_pins {clocks|pll|pll|clk[1]}] -divide_by 1 [get_ports DRAM_CLK]
set_clock_uncertainty -setup 0.200 -from [all_clocks] -to [all_clocks]
set_clock_uncertainty -hold 0.200 -from [all_clocks] -to [all_clocks]
# PSC A2V64S40CTP-G7: command setup 2ns, hold 1ns, CL2 tAC 6ns.
# Add 1ns total PCB/skew allowance on max paths; physical board budget unmeasured.
set dram_out [get_ports {DRAM_ADDR[*] DRAM_BA[*] DRAM_DQM[*] DRAM_CKE DRAM_CS_N DRAM_RAS_N DRAM_CAS_N DRAM_WE_N DRAM_DQ[*]}]
set_output_delay -clock sdram_pin -max 3.000 $dram_out
set_output_delay -clock sdram_pin -min -1.000 $dram_out
set_input_delay -clock sdram_pin -max 7.000 [get_ports {DRAM_DQ[*]}]
set_input_delay -clock sdram_pin -min 2.000 [get_ports {DRAM_DQ[*]}]
set_false_path -from [get_ports PS2_CLK] -to [get_registers {*|clock_sync[0]}]
set_false_path -from [get_ports PS2_DAT] -to [get_registers {*|data_sync[0]}]
set_false_path -from [get_ports {KEY[0]}] -to [get_registers {cpu_reset[*]}]
set_false_path -to [get_ports {LEDR[0]}]
set video_ports [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS}]
set_max_delay 10.000 -to $video_ports
set_min_delay 0.000 -to $video_ports

# Device input capacitance plus provisional PCB allowance, in pF.
# Output load specified using QSF OUTPUT_PIN_LOAD (legacy TimeQuest).

# Cyclone II's dedicated JTAG user-TCK hard-block output is not connected
# by a normal timing arc to the auto-created reserved-TCK clock. Constrain
# that physical clock root explicitly; do not leave the hub/ISSP unclocked.
create_clock -name jtag_user -period 100.000 [get_pins {altera_internal_jtag|tckutap}]
# Source data is held until CPU ACK. Only the command crosses via explicit
# synchronizers and a further two-clock settling delay in jtag_mailbox.v.
set_clock_groups -asynchronous -group [get_clocks {jtag_user altera_reserved_tck}] -group [get_clocks {osc clocks|pll|pll|clk[0] clocks|pll|pll|clk[1] sdram_pin}]
# Apply the same 200 ps uncertainty to the added JTAG clock domain.
set_clock_uncertainty -setup 0.200 -from [get_clocks jtag_user] -to [get_clocks jtag_user]
set_clock_uncertainty -hold 0.200 -from [get_clocks jtag_user] -to [get_clocks jtag_user]
