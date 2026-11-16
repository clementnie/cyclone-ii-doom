load_package insystem_source_probe
source <checkout>/phase6/tools/issp_discovery.tcl
set cable {USB-Blaster [1-1]}
set device {@1: EP2C(15|20) (0x020B30DD)}
set idx [doom6::discover $cable $device auto]
start_insystem_source_probe -hardware_name $cable -device_name $device
puts "INITIAL_PROBE=[read_probe_data -instance_index $idx -value_in_hex]"
end_insystem_source_probe
