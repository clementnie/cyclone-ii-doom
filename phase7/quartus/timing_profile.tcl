package require ::quartus::sta
project_open phase7_profile
create_timing_netlist
read_sdc
update_timing_netlist
report_clocks -file ../reports/profile-clocks.txt
report_clock_transfers -file ../reports/profile-transfers.txt
check_timing -file ../reports/profile-check-timing.txt
report_ucp -file ../reports/profile-unconstrained.txt
foreach corner {slow fast} {
 set_operating_conditions -model $corner
 update_timing_netlist
 foreach type {setup hold} {
  report_timing -$type -from [get_ports {DRAM_DQ[*]}] -npaths 16 -detail full_path -file ../reports/profile-${corner}-sdram-in-${type}.txt
  report_timing -$type -to [get_ports {DRAM_DQ[*] DRAM_ADDR[*] DRAM_BA[*] DRAM_DQM[*] DRAM_RAS_N DRAM_CAS_N DRAM_WE_N}] -npaths 32 -detail full_path -file ../reports/profile-${corner}-sdram-out-${type}.txt
 }
 foreach type {setup hold recovery removal} {
  report_timing -$type -npaths 20 -detail full_path -file ../reports/profile-${corner}-${type}.txt
 }
}
delete_timing_netlist
project_close
