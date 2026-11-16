package require ::quartus::sta
project_open phase6
create_timing_netlist
read_sdc
update_timing_netlist
help -cmd get_register_info
help -cmd get_fanins
help -cmd get_pin_info
foreach_in_collection r [get_registers {*hold_reg*}] {puts "REG [get_register_info -name $r]"; break}
foreach_in_collection p [get_pins -hierarchical {*tck*}] {puts "PIN [get_pin_info -name $p]"}
delete_timing_netlist
project_close
