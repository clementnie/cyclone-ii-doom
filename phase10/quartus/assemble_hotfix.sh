#!/bin/sh
set -eu
cd "$(dirname "$0")"
python3 ../tools/check_release.py
export QUARTUS_64BIT=0
q=${QUARTUS_BIN:?Set QUARTUS_BIN to the Quartus II 13.0 SP1 bin directory}
"$q/quartus_asm" phase10 > ../reports/hotfix/assembly.log 2>&1
stamp=$(date -u +%Y%m%dT%H%M%SZ)
name="doom_chromatix_160x100_block32_crcfix_DA000001_$stamp.sof"
cp output_files/phase10.sof "../candidates/$name"
(cd ../candidates && sha256sum "$name" > "$name.sha256")
echo "../candidates/$name"
