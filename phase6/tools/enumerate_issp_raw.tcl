load_package insystem_source_probe
puts "TCL=[info patchlevel]"
set cable {USB-Blaster [1-1]}
puts "CABLE=<$cable>"
set devices [get_device_names -hardware_name $cable]
puts "DEVICES_RAW=<$devices>"
foreach device $devices {
 puts "DEVICE=<$device>"
 set raw [get_insystem_source_probe_instance_info -hardware_name $cable -device_name $device]
 puts "INSTANCE_INFO_RAW_BEGIN"
 puts $raw
 puts "INSTANCE_INFO_RAW_END"
 puts "INSTANCE_INFO_LIST_LENGTH=[llength $raw]"
 foreach item $raw {
  puts "ITEM=<$item> FIELDS=[llength $item]"
  for {set i 0} {$i<[llength $item]} {incr i} {puts "FIELD_$i=<[lindex $item $i]>"}
 }
}
