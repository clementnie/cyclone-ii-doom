# Exactly one ISSP session for all packets. No FPGA configuration command.
load_package insystem_source_probe
if {[llength $argv]<3 || [llength $argv]>4} {error "upload.tcl packets cable device ?index|auto?"}
lassign $argv path cable device requested
if {[llength $argv]==3} {set requested auto}
source [file join [file dirname [info script]] issp_discovery.tcl]
set idx [doom6::discover $cable $device $requested]
start_insystem_source_probe -hardware_name $cable -device_name $device
# Reconcile a stale command after CPU reset or interrupted/repeated upload.
# Zero is an invalid opcode that invalidates any old session; RESET follows.
write_source_data -instance_index $idx -value 0 -value_in_hex
set deadline [expr {[clock milliseconds]+180000}]
while {1} {
 set pre [read_probe_data -instance_index $idx -value_in_hex]
 if {[regexp -nocase {^[de]6[0-9a-f]*00000000$} $pre]} {break}
 if {[clock milliseconds]>$deadline} {error "ROM loader not ready; press KEY0 and retry"}
}
set f [open $path r]
set count 0
set started [clock milliseconds]
set failed [catch {
 while {[gets $f packet]>=0} {
  if {![regexp {^[0-9a-f]{120}$} $packet]} {error "malformed packet"}
  set cmd [string range $packet 112 119]
  write_source_data -instance_index $idx -value $packet -value_in_hex
  set deadline [expr {[clock milliseconds]+180000}]
  while {1} {
   set probe [format %024s [read_probe_data -instance_index $idx -value_in_hex]]
   set probe [string map {" " 0} $probe]
   if {[string equal -nocase [string range $probe end-7 end] $cmd]} {break}
   if {[clock milliseconds]>$deadline} {error "ACK timeout cmd=$cmd; reset board and rerun entire upload"}
  }
  scan [string range $probe 0 7] %x status
  if {($status & 0xff000000)==0xe6000000} {error "loader rejected cmd=$cmd status=[format %08x $status]"}
  if {[string range $cmd 0 1]=="04"} {
   set want [string range $packet 96 103]
   if {![string equal -nocase [string range $probe 8 15] $want]} {error "readback CRC mismatch"}
  }
  incr count
  if {$count%1024==0} {puts "ACKed $count packets, elapsed [expr {([clock milliseconds]-$started)/1000}]s"}
 }
} why]
close $f
end_insystem_source_probe
if {$failed} {error $why}
puts "Uploaded and verified $count packets; entry handoff acknowledged. Observe VGA."
