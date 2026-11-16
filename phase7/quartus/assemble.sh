#!/bin/sh
set -eu
cd "$(dirname "$0")"
python3 ../tools/check_release.py
export QUARTUS_64BIT=0
q=${QUARTUS_BIN:?Set QUARTUS_BIN to the Quartus II 13.0 SP1 bin directory}
"$q/quartus_asm" phase7 > ../reports/assembly.log 2>&1
"$q/quartus_asm" phase7_profile > ../reports/profile-assembly.log 2>&1
mkdir -p ../candidates
stamp=$(date -u +%Y%m%dT%H%M%SZ)
cp output_files/phase7.sof "../candidates/doom_icache4k_D7000001_$stamp.sof"
cp output_files_profile/phase7_profile.sof "../candidates/doom_profile_uncached_D7000001_$stamp.sof"
cd ../candidates
sha256sum *.sof > SHA256SUMS
