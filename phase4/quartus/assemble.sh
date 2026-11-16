#!/bin/sh
# Assemble a REFERENCE-BOARD CANDIDATE; no JTAG tools, no programming.
set -eu
cd "$(dirname "$0")"
python3 ../tools/audit.py
python3 ../tools/check_timing.py
python3 ../tools/build_manifest.py verify
export QUARTUS_64BIT=0
q=${QUARTUS_BIN:?Set QUARTUS_BIN to the Quartus II 13.0 SP1 bin directory}
# Run the normal full flow, including the preserved pre-flow hardware hook.
"$q/quartus_sh" --flow compile phase4 > ../reports/full-compile.log 2>&1
"$q/quartus_sta" -t timing.tcl > ../reports/timing.log 2>&1
python3 ../tools/check_timing.py
cp output_files/phase4.fit.summary ../reports/resource-summary.txt
cp output_files/phase4.fit.rpt ../reports/phase4.fit.rpt
cp output_files/phase4.asm.rpt ../reports/phase4.asm.rpt
mkdir -p ../candidates
cp output_files/phase4.sof ../candidates/reference_sdram_D4000001.sof
cd ../candidates
sha256sum reference_sdram_D4000001.sof > SHA256SUMS
