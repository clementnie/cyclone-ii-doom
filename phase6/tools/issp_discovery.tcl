# Read-only metadata validation shared by enumeration and the uploader.
# Quartus 13 altsource_probe_body.vhd uses INSTANCE_ID_LENGTH = 4*BYTE and
# serialize_instance_id walks backwards through at most four characters.
# Thus the existing RTL instance_id("DOOM6") is exactly "OOM6" on the wire.
namespace eval doom6 {}
proc doom6::select_instance {raw {requested auto}} {
 if {$requested ne "auto" && (![string is integer -strict $requested] || $requested<0)} {
  error "instance index must be auto or a nonnegative integer"
 }
 set matches {}
 set seen {}
 foreach item $raw {
  if {[llength $item]!=4} {error "Malformed ISSP metadata record: <$item>; raw=<$raw>"}
  lassign $item index source_width probe_width identity
  foreach value [list $index $source_width $probe_width] {
   if {![string is integer -strict $value] || $value<0} {error "Malformed ISSP metadata record: <$item>"}
  }
  if {[lsearch -exact $seen $index]>=0} {error "Duplicate ISSP instance index $index; raw=<$raw>"}
  lappend seen $index
  # Exact known identities only: Quartus 13's four-byte wire ID, or the
  # literal logical name on a tool exposing the full string. No suffix or
  # case-insensitive wildcard matching and no width-only fallback.
  if {$source_width==480 && $probe_width==96 &&
      ($identity eq "OOM6" || $identity eq "DOOM6") &&
      ($requested eq "auto" || $index==$requested)} {lappend matches $index}
 }
 if {[llength $matches]!=1} {
  error "Expected one DOOM6 mailbox (wire ID OOM6, source 480, probe 96), requested index=$requested; matches=[llength $matches]; raw=<$raw>"
 }
 return [lindex $matches 0]
}
proc doom6::discover {cable device {requested auto}} {
 if {![regexp -nocase {\(0x020b30dd\)$} $device]} {
  error "Expected EP2C20-family JTAG ID 0x020B30DD; selected device=<$device>"
 }
 set raw [get_insystem_source_probe_instance_info -hardware_name $cable -device_name $device]
 puts "ISSP instance info raw: <$raw>"
 set index [doom6::select_instance $raw $requested]
 foreach item $raw {if {[lindex $item 0]==$index} {set identity [lindex $item 3]}}
 puts "Verified DOOM6 mailbox: device=$device index=$index source=480 probe=96 reported_id=$identity"
 return $index
}
