load_package insystem_source_probe
source <checkout>/phase6/tools/issp_discovery.tcl
set cable {USB-Blaster [1-1]}
set device {@1: EP2C(15|20) (0x020B30DD)}
set idx [doom6::discover $cable $device auto]
start_insystem_source_probe -hardware_name $cable -device_name $device
set f [open phase10/build/hotfix/diag.hex r]
while {[gets $f packet]>=0} {
 set cmd [string range $packet 112 119]
 write_source_data -instance_index $idx -value $packet -value_in_hex
 set deadline [expr {[clock milliseconds]+180000}]
 while {1} {
  set probe [read_probe_data -instance_index $idx -value_in_hex]
  if {[string equal -nocase [string range $probe end-7 end] $cmd]} {break}
  if {[clock milliseconds]>$deadline} {error "timeout $cmd $probe"}
 }
 if {[string range $cmd 0 1]=="04"} {puts "END $cmd want=[string range $packet 96 103] probe=$probe"}
 if {[string range $probe 0 1]=="E6" && [string range $cmd 0 1]!="04"} {error "rejected $cmd $probe"}
}
close $f
end_insystem_source_probe
