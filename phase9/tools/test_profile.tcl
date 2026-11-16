# Transport stubs only; no FPGA access.
proc load_package {name} {}
proc get_insystem_source_probe_instance_info {args} {return {{0 480 96 OOM6}}}
proc start_insystem_source_probe {args} {}
proc end_insystem_source_probe {} {}
set ::reply d9000001000000007e000001
set ::snapshot 0
proc write_source_data {args} {
 set packet [lindex $args 3]
 if {[string length $packet]!=120} {error "480-bit framing"}
 set cmd [string range $packet end-7 end]
 scan [string range $packet end-15 end-8] %x index
 if {[string range $cmd 0 1] eq "7e"} {incr ::snapshot}
 set ::reply [format "d9000001%08x%s" [expr {100+$index}] $cmd]
}
proc read_probe_data {args} {return $::reply}
set argv [list {USB-Blaster [1-1]} {@1: EP2C(15|20) (0x020B30DD)}]
source phase9/tools/profile.tcl
if {$::snapshot!=1} {error "exactly one snapshot required"}
puts "PASS profiler transport: preserved mailbox identity, 480/96 framing, sequence/ACK, one snapshot and 32 selections"
