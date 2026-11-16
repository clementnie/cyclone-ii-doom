# Read-only enumeration and identity validation. Never opens a source/probe
# session and never writes source data, resets, uploads or programs hardware.
load_package insystem_source_probe
source [file join [file dirname [info script]] issp_discovery.tcl]
if {[llength $argv]==2} {
 lassign $argv cable device
 doom6::discover $cable $device
} elseif {[llength $argv]==0} {
 foreach cable [get_hardware_names] {
  puts "CABLE: $cable"
  foreach device [get_device_names -hardware_name $cable] {
   puts "DEVICE: $device"
   set raw [get_insystem_source_probe_instance_info -hardware_name $cable -device_name $device]
   puts "ISSP instance info raw: <$raw>"
  }
 }
} else {error "list_jtag.tcl ?cable device?"}
