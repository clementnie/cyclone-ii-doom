source [file join [file dirname [info script]] issp_discovery.tcl]
set tests 0
proc accepts {label raw requested expected} {
 incr ::tests
 set actual [doom6::select_instance $raw $requested]
 if {$actual!=$expected} {error "$label: got $actual wanted $expected"}
}
proc rejects {label raw {requested auto}} {
 incr ::tests
 if {![catch {doom6::select_instance $raw $requested}]} {error "$label: unsafe metadata accepted"}
}
accepts physical {{0 480 96 OOM6}} auto 0
accepts literal {{0 480 96 DOOM6}} auto 0
accepts nonzero {{11 480 96 OOM6}} auto 11
accepts selected {{11 480 96 OOM6}} 11 11
accepts unrelated {{0 32 32 TEST} {7 480 96 OOM6}} auto 7
accepts disambiguated {{1 480 96 OOM6} {7 480 96 OOM6}} 7 7
accepts whitespace "\n {0 480 96 OOM6}\n" auto 0
rejects empty {}
rejects wrong_order {{0 OOM6 480 96}}
rejects wrong_source {{0 479 96 OOM6}}
rejects wrong_probe {{0 480 95 OOM6}}
rejects wrong_identity {{0 480 96 TEST}}
rejects wrong_case {{0 480 96 oom6}}
rejects prefix {{0 480 96 XOOM6}}
rejects suffix {{0 480 96 OOM6X}}
rejects wrong_index {{7 480 96 OOM6}} 0
rejects ambiguous {{0 480 96 OOM6} {7 480 96 OOM6}}
rejects duplicate_index {{0 32 32 TEST} {0 480 96 OOM6}}
rejects missing_field {{0 480 96}}
rejects extra_field {{0 480 96 OOM6 unexpected}}
rejects negative {{-1 480 96 OOM6}}
rejects invalid_index {{0 480 96 OOM6}} invalid
rejects malformed_integer {{0 480x 96 OOM6}}
# Device rejection must happen before any hardware API call.
proc get_insystem_source_probe_instance_info {args} {error "unexpected hardware call"}
incr tests
if {![catch {doom6::discover cable {@1: other (0x12345678)}} e] || ![string match {*Expected EP2C20*} $e]} {error "wrong FPGA ID accepted"}
# Negative discovery must stop the actual uploader before session/source writes.
proc load_package {name} {}
set ::starts 0
set ::writes 0
proc start_insystem_source_probe {args} {incr ::starts;error UNSAFE_SESSION}
proc write_source_data {args} {incr ::writes;error UNSAFE_SOURCE_WRITE}
proc get_insystem_source_probe_instance_info {args} {return $::bad_info}
foreach bad_info [list {} {{0 480 96 TEST}} {{0 96 480 OOM6}} {{0 480 95 OOM6}} {{0 480 96 OOM6} {7 480 96 OOM6}}] {
 incr tests
 set argv [list unused-packets cable {@1: EP2C(15|20) (0x020B30DD)} auto]
 if {![catch {source [file join [file dirname [info script]] upload.tcl]} e]} {error "invalid identity accepted by uploader"}
 if {$::starts || $::writes || [string match {*UNSAFE*} $e]} {error "discovery failure touched hardware session/source"}
}
puts "PASS ISSP discovery: $tests cases; exact physical/literal identities, widths, field order, index discovery, ambiguity, malformed data, FPGA ID"
