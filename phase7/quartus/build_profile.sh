#!/bin/sh
set -eu
cd "$(dirname "$0")"
export QUARTUS_64BIT=0
q=${QUARTUS_BIN:?Set QUARTUS_BIN to the Quartus II 13.0 SP1 bin directory}
"$q/quartus_map" phase7_profile > ../reports/profile-synthesis.log 2>&1
"$q/quartus_fit" phase7_profile > ../reports/profile-fitting.log 2>&1
"$q/quartus_sta" -t timing_profile.tcl > ../reports/profile-timing.log 2>&1
cp output_files_profile/phase7_profile.fit.summary ../reports/profile-resource-summary.txt
