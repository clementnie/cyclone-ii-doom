# Phase 6: real engine boot and JTAG development loader

This is a separate project from all physically verified Phase 2/4/4B
releases. It never programs the FPGA automatically and never writes Flash.
The release status and physical gate are recorded in `HARDWARE_TEST.md`.

See [ISSP_HOTFIX.md](ISSP_HOTFIX.md) for the physical OOM6 identity correction,
verified read-only discovery and the next authorized upload command. The
existing SOF is retained.

## Software and assets

Use the existing Clang, lld and LLVM utilities. Verilator 5.054 was extracted
into `/tmp/phase6-verilator` without a system installation. Set VERILATOR
and VERILATOR_ROOT in Make to use another installation. Icarus regressions
use the existing `/tmp/de2-iverilog` installation. Quartus is the existing
32-bit 13.0 SP1 installation.

From the repository root:

```sh
python3 phase6/tools/acquire_iwad.py
make -C phase6 engine loader
python3 phase6/tools/upload.py   # validates and packs; does NOT access hardware
make -C phase6 cpu-sim
make -C phase6 full-sim
python3 phase6/tools/test_upload.py
python3 phase6/tools/test_loader.py
make -C phase6 mailbox-test
tclsh phase6/tools/test_upload_tcl.tcl
make -C phase4b test
make -C phase4 regression
```

The acquisition script downloads the intact shareware package from
https://image.dosgamesarchive.com/games/doom19s.zip, joins its original
installer volumes, uses Python ZIP extraction without running DOS code,
checks pinned SHA256 hashes, preserves the original distribution locally,
and validates every lump. IWAD: 4,196,020 bytes, 1,264 lumps, MD5
`f0cefca49926d00903cf57551d901abe`. Assets and rendered captures are ignored
by Git. No commercial IWAD is imported. `reports/iwad.json` records hashes.
The initial local search found Half-Life WADs, not a usable DOOM IWAD.

Phase 6 reuses the complete upstream engine and Phase 5 runtime, with a
measured startup CRC improvement, heap high-address instrumentation, and
`-warp 1 1 -skill 3 -mb 2 -nosound -nomusic` for an immediate E1M1 test.
Existing engine/source checkpoints are not edited. Save/config writes
remain explicitly unsupported. The seven original PS/2 keys provide arrows,
Ctrl/fire, Space/use and Esc. Enter/menu selection is not added here; E1M1
starts directly. Reset returns to the loader and requires a fresh upload.

## Simulation interpretation

`sim/boot.cpp` executes the unchanged Phase 4 CPU RTL with a functional
bounded bus model. It loads ELF PT_LOAD initialized bytes, deliberately
poisons BSS/RAM before startup, and executes the ELF's own startup routine.
Optional loader mode instead starts the actual ROM firmware and sends the
same framed packets as the host, with no engine/WAD preload.
The model does not establish SDRAM latency or VGA arbitration performance.

`sim/full.cpp` runs Phase 6's complete RTL SoC, including the unchanged CPU,
SDRAM controller, arbiter, framebuffer and PS/2 modules. It uploads the
entire engine and WAD through the source/probe mailbox model, starts at ROM
reset, and captures real VGA RGB/sync outputs. The independent C++ SDRAM
model implements four banks, BL1/CL2, byte masks, initialization and command
checks. Electrical delay verification remains the separate unchanged
Icarus command-level model with +8 ns clock, +6 ns data and +1 ns hold.
Neither is evidence of physical FPGA operation.

`reports/title-boot.json` is the first title-screen CPU run before the
warp/CRC changes. Subsequent logs trace actual initialization and rendered
frames. `reports/loader-boot.json` measures heap span and stack depth for
50 E1M1 frames using the actual ROM firmware on CPU RTL. Heap span is the
highest malloc block end minus the arena start, including allocator
metadata; it is not simultaneous live memory or zone occupancy. Stack
measurement samples the CPU's SP. No heap/stack collision margin is reduced.

The first melt-transition image can contain uninitialized pixels; later
captures show the rendered starting room, pistol and HUD. No test pattern
or fabricated splash is used. The local PPM/PNG captures are generated from
engine framebuffers or VGA outputs and are not source artwork.

## Build a candidate

```sh
python3 phase6/tools/check_release.py snapshot
sh phase6/quartus/build.sh
python3 phase6/tools/check_release.py
sh phase6/quartus/assemble.sh
```

Release checks reject changed source hashes, missing full boot evidence,
regression failures, negative setup/hold slack, unclocked registers and
incomplete SDRAM timing constraints. The original 20 ns system clock,
+8 ns SDRAM clock, external delays and uncertainty are retained. JTAG adds
a 10 MHz constraint at the dedicated internal TCK root and documented
asynchronous crossings with command synchronization/bundled stable data.
`reports/synchronizer-metadata.txt` explains a Cyclone II preservation
annotation correction and confirms identical simulation translation units.
The sole clock-output UCP is DRAM_CLK, the forwarded reference itself.

## Measured result before physical testing

The complete SoC run passed at 4,541,040,002 clocks: three engine frames and
two complete VGA rasters, zero underflows and no CPU trap. The actual VGA
capture is `artifacts/vga.png` (generated locally, ignored by Git), showing
the real E1M1 room and HUD at the board's 2x scale. RGB CRC32 is `aafe7c69`;
framebuffer A CRC32 is `50c3c06f`. `reports/results.json` records checksums,
PC/frame checkpoints, capacity measurements and model performance.

All 92,693 source/probe packets passed actual ROM-firmware readback CRC and
entry handoff in the full SoC, with no executable or IWAD memory preload.
The model's first engine frame was at 4,059,713,734 clocks (81.19 s at
50 MHz including simulated upload). Frames 2..3 were 199,085,416 clocks
apart: 3.98 s, or 0.251 frames/s for that startup interval. This includes
startup/melt work; it is not a steady gameplay benchmark or a physical FPS
measurement. Expect a slow initial demonstration. Do not infer interactive
performance from the faster functional-bus simulation.

Final Fitter use: 8,588/18,752 logic elements (46%), 159,872/239,616 memory
bits (67%). Worst reported setup slack is +2.069 ns and hold +0.215 ns
across slow/fast models; all twelve SDRAM/internal setup/hold checks pass.
TimeQuest reports zero unclocked registers and no generated-clock issues.
The forwarded clock output remains the explicit clock-reference UCP.
Native Python/framing checks, ten negative/timeout ROM tests, the asynchronous
mailbox test, all 92,693 packets in Quartus 13 Tcl with stub transport, and
all existing Phase 4/4B regressions passed. Physical ISSP transport, SDRAM
execution, actual video, keys and FPS remain to be checked on this candidate.
