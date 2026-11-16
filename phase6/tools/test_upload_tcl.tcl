fconfigure stdout -buffering line
puts "Uploader Tcl stub starting on Tcl [info patchlevel]"
# Exercise the real upload Tcl script with a pure Tcl ISSP transport stub.
# This tests framing/checksum field parsing and session cleanup, not JTAG.
proc load_package {name} {}
proc get_insystem_source_probe_instance_info {args} {return $::instance_info}
set instance_info {{7 480 96 OOM6}}
if {[info exists ::env(PHASE6_TCL_LITERAL_ID)]} {set instance_info {{7 480 96 DOOM6}}}
set session 0
proc start_insystem_source_probe {args} {set ::session 1}
proc end_insystem_source_probe {} {set ::session 0}
set probe d60000010000000000000000
set words 0
proc write_source_data {args} {
 if {[lindex $args 1]!=7} {error "uploader did not use discovered index 7"}
 set value [lindex $args 3]
 if {$value eq "0"} {set ::probe e600000c0000000000000000;return}
 set cmd [string range $value 112 119]
 set op [string range $cmd 0 1]
 if {$op=="04"} {set crc [string range $value 96 103]} else {set crc 00000000}
 set ::probe "d60000${op}${crc}${cmd}"
 incr ::words
}
proc read_probe_data {args} {
 if {[lindex $args 1]!=7} {error "probe did not use discovered index 7"}
 return $::probe
}
# Use every control/CRC packet and the first DATA packet in each region.
# Bulk packet generation is covered separately by Python/CPU simulations.
set f [open phase6/build/upload.hex r]
set fixture phase6/build/upload-tcl-fixture.hex
set out [open $fixture w]
set lastop ""
set expected 0
while {[gets $f line]>=0} {
 set op [string range $line 112 113]
 if {[info exists ::env(PHASE6_TCL_ALL)] || $op!="03" || $lastop!="03"} {puts $out $line;incr expected}
 set lastop $op
}
close $f
close $out
set argv [list $fixture stub-cable {@1: EP2C(15|20) (0x020B30DD)} auto]
source phase6/tools/upload.tcl
if {$session||$words!=$expected} {error "session/packet count: $session / $words"}
puts "PASS host Tcl: all packets, ACK parsing, readback CRC field, stale-source recovery, cleanup"
