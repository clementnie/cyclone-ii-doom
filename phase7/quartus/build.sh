#!/bin/sh
set -eu
cd "$(dirname "$0")"
export QUARTUS_64BIT=0
q=${QUARTUS_BIN:?Set QUARTUS_BIN to the Quartus II 13.0 SP1 bin directory}
"$q/quartus_map" phase7 > ../reports/synthesis.log 2>&1
"$q/quartus_fit" phase7 > ../reports/fitting.log 2>&1
"$q/quartus_sta" -t timing.tcl > ../reports/timing.log 2>&1
cp output_files/phase7.fit.summary ../reports/resource-summary.txt

cp output_files/phase7.fit.rpt ../reports/phase7.fit.rpt
