#!/bin/sh
set -eu
cd "$(dirname "$0")"
python3 ../tools/audit.py
python3 ../tools/build_manifest.py snapshot
export QUARTUS_64BIT=0
q=${QUARTUS_BIN:?Set QUARTUS_BIN to the Quartus II 13.0 SP1 bin directory}
"$q/quartus_map" phase4b > ../reports/synthesis.log 2>&1
"$q/quartus_fit" phase4b > ../reports/fitting.log 2>&1
"$q/quartus_sta" -t timing.tcl > ../reports/timing.log 2>&1
python3 ../tools/check_timing.py
cp output_files/phase4b.fit.summary ../reports/resource-summary.txt
cp output_files/phase4b.fit.rpt ../reports/phase4b.fit.rpt
