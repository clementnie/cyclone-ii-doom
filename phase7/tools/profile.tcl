# Explicit hardware diagnostic writes: run manually only after DOOM handoff.
# Reuses 480/96 ISSP; commands 7e snapshot and 7f select do not involve CPU.
load_package insystem_source_probe
source [file join [file dirname [info script]] ../../phase6/tools/issp_discovery.tcl]
if {[llength $argv]!=2} {error "profile.tcl cable device"}
lassign $argv cable device
set idx [doom6::discover $cable $device]
set names {cycles retired fetch_requests fetch_stalls data_stalls sdram_reads sdram_writes refresh_wait framebuffer_writes underflows engine_frames frame_cycles fetch_wait_sum fetch_wait_max data_wait_sum data_wait_max cache_hits cache_misses vga_contention refreshes activates columns mul_entries div_entries data_requests frame_retired frame_fetch_stalls frame_data_stalls reserved28 reserved29 reserved30 reserved31}
start_insystem_source_probe -hardware_name $cable -device_name $device
set initial [read_probe_data -instance_index $idx -value_in_hex]
scan [string range $initial end-7 end] %x old_ack
set seq [expr {$old_ack&0xffffff}]
set failed [catch {
 for {set i -1} {$i<32} {incr i} {
  incr seq
  set op [expr {$i<0?0x7e:0x7f}]
  set command [expr {($op<<24)|($seq&0xffffff)}]
  set sel [expr {$i<0?0:$i}]
  set value [format "%0104d%08x%08x" 0 $sel $command]
  write_source_data -instance_index $idx -value $value -value_in_hex
  set deadline [expr {[clock milliseconds]+5000}]
  while {1} {
   set p [read_probe_data -instance_index $idx -value_in_hex]
   set p [string map {" " 0} [format %024s $p]]
   if {[string equal -nocase [string range $p end-7 end] [format %08x $command]]&&[string equal -nocase [string range $p 0 7] d7000001]} {break}
   if {[clock milliseconds]>$deadline} {error "Phase7 profiling ACK timeout; do not use on Phase6"}
  }
  if {$i>=0} {scan [string range $p 8 15] %x v;puts "[lindex $names $i] [expr {$v&0xffffffff}]"}
 }
} why]
end_insystem_source_probe
if {$failed} {error $why}
