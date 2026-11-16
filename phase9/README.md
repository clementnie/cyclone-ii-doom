# Phase 9 hardware candidate

Isolated from Phase 6/7 releases and Phase 8 experiments. Pre-change Git
checkpoint: `621cbac`. No board programming or Flash operation is automated.

Final verification: 14,732/18,752 LEs, 52/52 M4Ks, eight 9-bit multiplier
elements, one PLL. Worst setup/hold slack +2.069/+0.215 ns; both timing
corners and SDRAM paths pass. Focused tests and the integrated suite pass
with the demo fixture correction described below. One bounded DOOM boot
completed three real engine frames and two raster captures with zero
underflows in 463.578 host seconds. This covers the opening melt, not steady
gameplay. See `reports/final-results.json` and `artifacts/phase9-vga.png`.

Architecture: fetch/operand/execute stages with a one-entry speculative fetch
queue; fetch overlaps the interlocked backend. Branches resolve in execute;
redirects discard queued and outstanding wrong-path responses. Dependencies
(including load-use and branch operands) are conservatively interlocked by
serializing operand-read/execute. There is no claim of one instruction/cycle
or a fully bypassed five-stage pipeline. Traps remain precise stopping traps,
matching the original machine; reset clears all architectural/cache state.
All eight RV32M operations are supported: registered DSP multiplication and
32-step restoring division, including signed overflow and division by zero.

Memory: the existing 4 KiB data array is divided into independent 2 KiB I and
2 KiB D direct-mapped caches with one-word lines and synchronous tag/data RAM.
D reads allocate aligned words, including byte/halfword requests; the CPU
extracts and sign-extends bytes. Invalid/misaligned transactions bypass the
cache so they cannot be hidden by hits. Writes are synchronous write-through,
no-write-allocate, and conservatively invalidate both banks at the index.
Stores also flush the fetch queue, preserving loader/self-modifying-code
coherency. MMIO and on-chip RAM/ROM bypass. VGA sees committed SDRAM stores;
there is no dirty cache or posted-write visibility problem. Open-row SDRAM,
refresh, VGA priority/fairness, PLL phase, pin assignments and constraints
are inherited unchanged from Phase 8. No SDRAM burst-mode changes are claimed.

Software: genuine upstream E1M1 at 320x200 with RV32IM `-O2` and no strict
aliasing. `FixedMul`'s signed 64-bit expression now lowers to hardware multiply
instructions. `FixedDiv` retains its original saturation/64-bit semantics;
64-bit divide still requires runtime code. Rendering's `R_DrawColumn` and
`R_DrawSpan` remain real indexed texture samplers; no prerecorded output or
resolution reduction is used. Presentation copies aligned words instead of
four byte loads plus shifts; memcpy/memset have aligned word paths. The WAD
mapping and content, palette synchronization and ROM loader are unchanged.

Performance target: 15–20 FPS is **not established**. The baseline's 0.815153
FPS at CPI 15.6194 implies approximately 3.93M instructions/frame. At 50MHz,
15FPS permits 3.333M cycles/frame, 20FPS 2.500M. Even CPI 1 requires fewer
instructions than that baseline. This frontend cannot sustain CPI 1: cache
hits still require lookup/response and bus rearm, and execution is interlocked.
The Phase 8 locality observations predict about 85–87% D read hits in a split
2K/2K organization but extra I misses versus 4K I. Multiply lowering and word
copies reduce instruction count; exact savings depend on the scene/compiler.
A provisional engineering range is 1–4 FPS, subject to physical measurement;
it is not a simulation or hardware result. 15FPS at full resolution is not a
credible promise for this candidate. Longer cache lines/bursts, faster cache
hit issue, a truly fully forwarded backend and eliminating presentation copy
remain opportunities, requiring further fit/timing/correctness work.

At 15FPS presentation alone needs 0.96MB/s reads and 0.96MB/s writes; VGA
requires about 3.8MB/s. These are payload lower bounds excluding instructions,
textures, refresh and BL1 command overhead. Nominal SDRAM pin bandwidth is
not a sustained CPU bandwidth estimate.

Rebuild/check from repository root (tool paths are in Makefile/tools;
`sh phase9/tools/setup_simulators.sh` restores temporary user-space simulators
on this Arch x86_64 host, with no sudo):

```sh
python3 phase9/build.py
llvm-nm -n phase9/artifacts/doom-rv32im.elf > phase9/build/symbols.txt
python3 phase6/tools/upload.py --elf phase9/artifacts/doom-rv32im.elf --out phase9/build/upload.hex
python3 phase9/tools/focused.py
python3 phase9/tools/regress.py
make -C phase9 build/full1/Vfull_top
# One bounded integrated boot, including ROM packet upload/CRC/handoff:
timeout 900 phase9/build/full1/Vfull_top phase9/build/upload.hex 4000000000 3 phase9 > phase9/reports/phase9-boot.log 2>&1
python3 phase9/tools/check_release.py snapshot
sh phase9/quartus/build.sh
python3 phase9/tools/check_release.py
sh phase9/quartus/assemble.sh
```

See `reports/` for evidence and `HARDWARE_TEST.md` for manual programming,
benchmark and rollback commands. A SOF is releasable only after the gate passes.

The original demo keyboard regression exposed a pre-existing fixture deadlock:
while video was disabled, demo firmware waited for a slot flip that disabled
video cannot acknowledge. `firmware/keyboard.c` corrects that demo wait only;
`tools/keyboard_fast.py` builds it in Phase 9 and uses a 100M-cycle watchdog
to allow frame-loop polling. The original failure log is retained. DOOM
firmware/RTL and hardware timing constraints were not changed for this fix.
The full-boot harness's inherited heap-span calculation uses legacy symbol
addresses; its heap_span field is not valid evidence for the new ELF.
