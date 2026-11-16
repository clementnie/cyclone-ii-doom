#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Legacy phase harnesses use these paths. Prefer an existing user-space install.
if [ ! -x /tmp/phase9-tools/usr/bin/iverilog ]; then
  mkdir -p /tmp/phase9-tools/usr/bin /tmp/phase9-tools/usr/lib
  for tool in iverilog vvp verilator; do
    ln -s "$(command -v "$tool")" "/tmp/phase9-tools/usr/bin/$tool"
  done
  ivl=${IVL_ROOT:-/usr/lib/x86_64-linux-gnu/ivl}
  [ -d "$ivl" ] || ivl=/usr/lib/ivl
  [ -d "$ivl" ] || { echo 'Set IVL_ROOT to the Icarus ivl directory' >&2; exit 1; }
  ln -s "$ivl" /tmp/phase9-tools/usr/lib/ivl
  mkdir -p /tmp/phase9-tools/usr/share
  vr=${VERILATOR_ROOT:-$(verilator -V | sed -n 's/^[[:space:]]*VERILATOR_ROOT[[:space:]]*=[[:space:]]*//p' | head -n 1)}
  [ -d "$vr" ] || { echo 'Set VERILATOR_ROOT to the Verilator data directory' >&2; exit 1; }
  ln -s "$vr" /tmp/phase9-tools/usr/share/verilator
fi
mkdir -p phase9/build phase9/reports phase9/artifacts
(cd phase2 && python3 tools/cpu_vectors.py)
make -C phase4b build/sim.hex
python3 phase9/tools/focused.py
python3 tools/test-phase9-integrated.py
