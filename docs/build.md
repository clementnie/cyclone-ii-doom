# Build, programming and rollback

All commands start at the repository root. The released pair is Phase 9,
signature **D9000001**. No board programming or Flash write was performed during
publication. The commands in the programming section are manual user actions.

## Tools and source

- Quartus II 13.0 SP1 Web Edition, 32-bit, with Cyclone II support. Recorded version:
  13.0.1 Build 232. Install separately, including host 32-bit runtime dependencies.
- Clang/LLVM 23.1.5, lld, llvm-nm, llvm-size, llvm-readelf and llvm-objcopy for the
  recorded firmware build. Other versions can produce different binaries.
- Python 3, GNU Make, C++ toolchain, Icarus Verilog 13.0 and Verilator 5.054
  for the recorded simulation workflow. See `phase9/reports/compiler.txt`.
- USB-Blaster and appropriate local device permissions for manual loading.

```sh
git clone git@github.com:clementnie/cyclone-ii-doom.git
cd cyclone-ii-doom
git checkout v0.1.0
make verify
```

The SOF and engine ELF are preserved unchanged. The boot ROM is
`phase6/firmware/boot.hex`; its source and linker/startup files are alongside it.
Do not rebuild this ROM simply to use the release. `make -C phase6 loader` rebuilds
it when deliberately developing a new hardware configuration.

## Byte-identical tested firmware

The tested ELF contains two `__FILE__` diagnostic strings with the original
checkout prefix. The owner explicitly approved publishing those ordinary paths.
A checkout elsewhere builds working source but changes these strings and the
ELF hash. This isolated helper maps only the compiler filename prefix back to the
reference, requires byte equality and leaves the tested artifact untouched:

```sh
python3 tools/rebuild-tested-elf.py
```

It requires the recorded Clang/LLVM toolchain. Output goes under ignored
`phase9/build/reproduced/`.

## Rebuild and simulate

Use a separate checkout for rebuilds so the released ELF stays available.

```sh
mkdir -p phase9/build phase9/reports phase9/artifacts
python3 phase9/build.py
llvm-nm -n phase9/artifacts/doom-rv32im.elf > phase9/build/symbols.txt
sh tools/test-phase9.sh
```

The helper adapts installed simulators to the older harness paths under `/tmp`;
set `IVL_ROOT` or `VERILATOR_ROOT` if their data directories differ. It runs
CPU retirement/traps, RV32M vectors, cache coherence, randomized SDRAM, integrated
framebuffer, keyboard and MMIO checks. It requires no WAD. Generated files stay
in ignored build directories; test reports are updated.

For a complete ROM-upload/engine simulation, supply your own authorized IWAD:

```sh
export WAD=/absolute/path/to/your/authorized/doom1.wad
python3 phase6/tools/upload.py --elf phase9/artifacts/doom-rv32im.elf --wad "$WAD" --out phase9/build/upload.hex
make -C phase9 build/full1/Vfull_top
 timeout 900 phase9/build/full1/Vfull_top phase9/build/upload.hex 4000000000 3 phase9 > phase9/reports/local-boot.log 2>&1
```

The bounded startup may take several host minutes. It is a correctness check,
not a gameplay benchmark. Its inherited `heap_span` report uses legacy symbol
addresses and is not valid heap evidence for Phase 9.

## FPGA rebuild

This is optional; use the tested SOF when running v0.1.0. No Quartus rebuild was
performed for publication. The phase directories must keep their relative paths.

```sh
export QUARTUS_BIN=/path/to/quartus/bin
export QUARTUS_64BIT=0
sh phase9/quartus/build.sh
python3 phase9/tools/check_release.py
sh phase9/quartus/assemble.sh
```

The gate checks exact RTL/ELF inputs and recorded simulation evidence, positive
slow/fast setup/hold including SDRAM I/O, fit limits and unchanged pins/constraints.
A deliberate source change needs freshly run tests, timing and a reviewed new
source snapshot. Do not call `snapshot` to conceal a mismatch. Quartus seeds,
compiler versions and tool installation can affect output bytes; reproducibility
means retained inputs and commands, with separate validation of each rebuilt pair.

## Program released SRAM configuration and upload

Download all assets from the v0.1.0 release into an empty directory and run
`sha256sum -c SHA256SUMS` there. Return to the checkout and set:

```sh
export QUARTUS_BIN=/path/to/quartus/bin
export QUARTUS_64BIT=0
export CABLE='USB-Blaster [1-1]'
export DEVICE='@1: EP2C(15|20) (0x020B30DD)'
export WAD=/absolute/path/to/your/authorized/doom1.wad
SOF=phase9/candidates/doom_pipeline_im_split2k_D9000001_20261114T201849Z.sof
"$QUARTUS_BIN/quartus_pgm" -m jtag -c "$CABLE" -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload --elf phase9/artifacts/doom-rv32im.elf --wad "$WAD" --out phase9/build/hardware-upload.hex --quartus-stp "$QUARTUS_BIN/quartus_stp" --cable "$CABLE" --device "$DEVICE"
```

Replace cable/device identifiers with those reported by your installation.
The `@1` in the programmer command must match the FPGA position in your chain.
Require all ACKs, segment/IWAD CRCs and EXEC handoff. Confirm E1M1, HUD,
movement, turning and fire. Wait for the wipe before measuring FPS.
A different/full-size IWAD may exceed the reserved slot or be untested.

## Rollback

From a Phase 10 experiment, restore the exact Phase 9 SOF and ELF above, then
use `phase9/tools/profile.tcl`. For the older physically working Phase 7 baseline:

```sh
SOF=phase8/baseline/doom_icache4k_D7000001_20261114T082224Z.sof
"$QUARTUS_BIN/quartus_pgm" -m jtag -c "$CABLE" -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload --elf phase8/baseline/doom-rv32i.elf --wad "$WAD" --out phase9/build/rollback-upload.hex --quartus-stp "$QUARTUS_BIN/quartus_stp" --cable "$CABLE" --device "$DEVICE"
```

Use `phase7/tools/profile.tcl` for signature D7000001. Never upload the RV32IM ELF
to the RV32I baseline. Both rollback artifacts are checksummed in the release
manifest. Power cycling removes volatile FPGA configuration; this workflow
writes no Flash.
