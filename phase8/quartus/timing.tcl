package require ::quartus::sta
project_open phase8
create_timing_netlist
read_sdc
update_timing_netlist
report_clocks -file ../reports/clocks.txt
report_clock_transfers -file ../reports/transfers.txt
check_timing -file ../reports/check-timing.txt
report_ucp -file ../reports/unconstrained.txt
foreach corner {slow fast} {
 set_operating_conditions -model $corner
 update_timing_netlist
 foreach type {setup hold} {
  report_timing -$type -from [get_ports {DRAM_DQ[*]}] -npaths 16 -detail full_path -file ../reports/${corner}-sdram-in-${type}.txt
  report_timing -$type -to [get_ports {DRAM_DQ[*] DRAM_ADDR[*] DRAM_BA[*] DRAM_DQM[*] DRAM_RAS_N DRAM_CAS_N DRAM_WE_N}] -npaths 32 -detail full_path -file ../reports/${corner}-sdram-out-${type}.txt
 }
 foreach type {setup hold recovery removal} {
  report_timing -$type -npaths 20 -detail full_path -file ../reports/${corner}-${type}.txt
 }
}
delete_timing_netlist
project_close
