# Phase 4B: 320x200 SDRAM framebuffer and RV32I DOOM platform

This project preserves D1060001, D4000001 and source checkpoint 1757c49.
`BASELINE.md` records the user's successful physical 8 MiB test.
Phase 4B is a separate project: `quartus/phase4b.qpf`, EP2C20F484C7,
32-bit Quartus II 13.0 SP1. No programmer is run by any build target.

## Reproduce

```sh
make -C phase4b firmware
make -C phase4b test
make -C phase4b regression
make -C phase4b doom-test
make -C phase4b quartus
make -C phase4b candidate
```

Icarus defaults to the installed `/tmp/de2-iverilog` tools. Override
IVERILOG, VVP, IVL_FLAGS as needed. Clang/lld/llvm-objcopy target RV32I/ILP32.
The Quartus scripts use the same proven 32-bit installation as Phase 4.
Tests can take several minutes because real RV32I firmware populates SDRAM.
`doom/engine-link` deliberately reports unresolved full-engine dependencies;
it is not required to assemble the framebuffer diagnostic.

## Data path and timing

The CPU writes actual indexed pixels to SDRAM; no RTL pattern generator
replaces those writes. Two line buffers fetch 80 words per 320-pixel source
row and reuse them for two VGA rows. A 256x12 RGB444 palette feeds registered
DAC outputs. Sync/blank coordinates are delayed with both synchronous RAM
stages. Output is 640x400 at 2x scale, vertically centered in 640x480.
Raster is the existing 25 MHz enable, 800x525, approximately 59.52 Hz.
All logic uses one 50 MHz system clock; the unchanged SDRAM forwarded clock
is the physically tested +8 ns PLL output. There are no pixel-clock CDCs.

Four pending display words then one waiting CPU word give deterministic
arbitration. Ownership/data/byte enables remain latched through completion.
The original SDRAM controller handles refresh without modification.
CPU responses are registered to cut the measured MMIO-to-load timing path;
slaves and arbiter keep their existing served/request-low rearm semantics.
The actual Phase 4 CPU and four-byte-array RAM source files are unchanged.
The registered response adds one wait cycle; the focused instruction and
legacy SoC regression still use the unchanged Phase 4 core.

Vblank-only slot selection avoids tearing when the CPU writes the inactive
buffer. Commit occurs at raster y=520, after the palette update window.
The palette has no shadow bank: update it during vblank, as the DG platform
does. A missed source-row deadline outputs black for invalid line tags and
increments a sticky counter; VGA never waits for memory. No FIFO exists to
overflow; two tagged line stores reject stale rows. Tests inject lateness,
DMA errors and reset and verify recovery on subsequent frames.

## Memory and registers

The complete budget/map is in `ARCHITECTURE.md`. Frame slots A/B start at
20000000/20010000; each has 64,000 live bytes and a 64 KiB reserved slot.
SDRAM 20020000..207FFFFF remains for code/data/heap/WAD. ROM 8 KiB and
on-chip RAM 8 KiB remain unchanged, as do original PS/2/video/system MMIO.

New MMIO at 10006000, naturally aligned 32-bit only:

| Offset | Function |
| --- | --- |
| 00 | Requested enable bit0; disable selects original diagnostics |
| 04 | Requested front slot bit0, latched only in vblank |
| 08 | Status: bit0 active, bit1 active slot, bit2 pending slot |
| 0c | Sticky underflow / DMA-error count, reset with CPU/video reset |
| 10 | Completed video SDRAM words |
| 14 | Completed CPU SDRAM requests |
| 18 | Maximum display request-to-completion clocks, includes arbitration |
| 1c | Hardware raster frame count |
| 20 | Current output scanline, for palette updates during vblank |
| 400..7fc | Write-only 256-entry RGB444 palette, bits11:0 |

Undefined/read-only/partial/fetch MMIO accesses fault. Slot/enable writes
use bit0. Pixel byte/halfword/word accesses retain the tested SDRAM semantics.

## Verification and physical gate

`reports/` preserves focused tests, full baseline regression, both-corner
SDRAM/internal timing, unconstrained paths, resources and full build logs.
The framebuffer CPU simulation compares three complete frames (1,260,000
pixels) while CPU stores contend with scanout. The scanout unit compares
2,100,000 reference pixels across palette, swap and recovery cases. A
separate real serialized PS/2 test exercises the CPU's rectangle movement
and Escape fallback. The linked DG platform-test ELF gets its own complete
420,000-pixel CPU/SDRAM/VGA comparison. All are software evidence.

`reference.png` is generated from the expected pixel function by
`python3 phase4b/tools/reference_image.py`; it is not a photograph. The
hardware image shows hex F/H/U counters and a CPU-driven moving rectangle.
See `HARDWARE_TEST.md` for exact expected behavior and manual test steps.
Stop at this physical gate before claiming framebuffer hardware verification.

## DOOM progress

`doom/platform.c` implements DG initialization, drawing, ticks, sleeping,
keyboard and title callbacks. All 81 selected engine/platform units compile
as RV32I, and a minimal platform-test executable links and passes the CPU
video test. Full engine executable linking remains blocked by the runtime
and file dependencies recorded in `reports/doom-engine-link.log`.
See `doom/README.md` and `doom/LOADING.md` for measured object sizes, heap /
stack map, source license, seven-key limitation and host-JTAG loader design.
No WAD is included. No engine launch, physical DOOM run or FPS is claimed.
