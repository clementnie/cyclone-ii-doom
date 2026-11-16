#!/bin/sh
# Volatile .sof only. No programmer, no .pof and no Flash action.
set -eu
cd "$(dirname "$0")"
python3 ../tools/check_release.py
export QUARTUS_64BIT=0
q=${QUARTUS_BIN:?Set QUARTUS_BIN to the Quartus II 13.0 SP1 bin directory}
"$q/quartus_asm" phase6 > ../reports/assembly.log 2>&1
mkdir -p ../candidates
stamp=$(date -u +%Y%m%dT%H%M%SZ)
hash=$(sha256sum ../artifacts/doom-rv32i.elf | cut -c1-12)
name=cyclone_ii_doom_D6000001_${stamp}_${hash}.sof
cp output_files/phase6.sof "../candidates/$name"
cd ../candidates
sha256sum "$name" > "$name.sha256"
printf '%s\n' "$name" > LATEST
