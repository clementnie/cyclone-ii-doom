#!/bin/sh
# Assemble only, never invoke a programmer. Preserve original pre-flow hook.
set -eu
cd "$(dirname "$0")"
python3 ../tools/audit.py
python3 ../tools/verify_tests.py
python3 ../tools/test_manifest.py verify
python3 ../tools/check_timing.py
export QUARTUS_64BIT=0
q=${QUARTUS_BIN:?Set QUARTUS_BIN to the Quartus II 13.0 SP1 bin directory}
"$q/quartus_sh" --flow compile phase4b > ../reports/full-compile.log 2>&1
"$q/quartus_sta" -t timing.tcl > ../reports/timing.log 2>&1
python3 ../tools/check_timing.py
cp output_files/phase4b.fit.summary ../reports/resource-summary.txt
cp output_files/phase4b.fit.rpt ../reports/phase4b.fit.rpt
cp output_files/phase4b.asm.rpt ../reports/phase4b.asm.rpt
mkdir -p ../candidates
cp output_files/phase4b.sof ../candidates/cyclone_ii_framebuffer_D4B00001.sof
cd ../candidates
sha256sum cyclone_ii_framebuffer_D4B00001.sof > SHA256SUMS
