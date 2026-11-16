#!/bin/sh
set -eu
cd "$(dirname "$0")"
export QUARTUS_64BIT=0
q=${QUARTUS_BIN:?Set QUARTUS_BIN to the Quartus II 13.0 SP1 bin directory}
"$q/quartus_map" phase8 > ../reports/synthesis.log 2>&1
"$q/quartus_fit" phase8 > ../reports/fitting.log 2>&1
"$q/quartus_sta" -t timing.tcl > ../reports/timing.log 2>&1
cp output_files/phase8.fit.summary ../reports/resource-summary.txt

cp output_files/phase8.fit.rpt ../reports/phase8.fit.rpt
