# Phase 7: measured fetch-path optimization

The physically working Phase 6 release is preserved in `baseline/`, at Git
checkpoint 0cff578 (original implementation 46b63ce, uploader fix 10ddbf5).
User-reported physical performance is 5–10 s/frame, visually estimated.
No Phase 7 programming or physical FPS measurement is performed by the agent.

The sole architectural optimization is a 4 KiB direct-mapped instruction
cache with one-word lines. Synchronous data/tag reads infer M4K. Data and
MMIO bypass; errors never fill. A CPU store invalidates a matching cached
word before its downstream write. Reset clears all valid bits. VGA DMA is
read-only; there is no other SDRAM writer. This preserves ROM loader writes
and instruction coherence, including byte/halfword stores. No D-cache,
bursts, multiply ISA, resolution, compiler flags or DOOM code changes.
The compatible ELF is byte-identical to the preserved working executable.
All requests incur the cache lookup pipeline, so ROM loading is slower;
the intended gain is repeated SDRAM instruction fetches during gameplay.

The original SDRAM controller closes the row after every 32-bit request:
one ACT, two BL1 x16 column commands, one PRE. There are no inter-request
row hits. CPU and VGA share four-video/one-CPU arbitration. Uncached fetches
pay the full transaction for every instruction. The prior complete boot
measured 228,268,982 retirements in 4,541,040,002 clocks (~19.9 CPI), including
ROM upload/startup. It is not a gameplay-only CPI measurement.

Reproduce, from the repository root:

```sh
make -C phase7 build/full0/Vfull_top build/full1/Vfull_top
phase7/build/full0/Vfull_top phase6/build/upload.hex 20000000000 3 > phase7/reports/baseline-boot.log 2>&1
cp phase7/reports/full-boot.json phase7/reports/baseline-boot.json
phase7/build/full1/Vfull_top phase6/build/upload.hex 20000000000 8 > phase7/reports/cached-boot.log 2>&1
cp phase7/reports/full-boot.json phase7/reports/cached-boot.json
python3 phase7/tools/analyze.py
python3 phase7/tools/regress.py
make -C phase4 test regression
sh phase7/quartus/build.sh
sh phase7/quartus/build_profile.sh
```

Both simulations start at ROM reset, send the real 92,693 JTAG-model
packets, verify executable/IWAD readback CRC, execute the unchanged DOOM
ELF, and capture actual VGA. They model the complete digital SoC, not host
JTAG timing or electrical SDRAM. Command-level delayed SDRAM regressions
remain part of the integrated tests. Baseline and cached runs must both
pass before assembly. Opening melt frames differ in workload: compare CPI,
fetch stalls and helper counts, and do not label a startup-frame ratio a
steady gameplay FPS improvement. Actual hardware A/B measurement is required.

The controller and arbiter copies add monitor output ports only. Their
state/command behavior remains the original implementation. CPU, VGA,
keyboard, ROM loader and engine remain unchanged. The simulation initially
observed those same monitor signals hierarchically; explicit ports make
them legal for Quartus synthesis. No timing constraint is relaxed.

## Hardware counters and atomic collection

The existing DOOM6 (wire ID OOM6), 480/96 ISSP instance is retained. After
DOOM has handed off and is displaying frames, manually run:

```sh
export QUARTUS_64BIT=0
Q=<quartus-bin>
"$Q/quartus_stp" -t phase7/tools/profile.tcl \
  'USB-Blaster [1-1]' '@1: EP2C(15|20) (0x020B30DD)' > phase7/reports/hardware-snapshot.txt
```

This is an explicit diagnostic source write, not a read-only enumeration;
it is not run automatically. Never run it on the original Phase 6 SOF or
while the ROM loader is active: unrecognized commands invalidate a loader
session. It does not change game memory or use CPU/bus cycles. Command 7e
snapshots all counters atomically; 7f selects a frozen word. The low 24 bits
are a changing sequence. Source word1 selects counter; remaining words zero.
Probe is `{D7000001,value,ack}`; poll matching ACK/signature. The original
loader probe is selected for all other opcodes. CPU keeps running during
snapshots. No reset is required between snapshots.

| Index | Counter |
|---|---|
| 0,1 | CPU clock cycles, retired instructions |
| 2,3,4 | Fetch requests, fetch wait cycles, data wait cycles |
| 5,6 | All controller read/write requests, including VGA reads |
| 7 | CPU-valid overlap with controller refresh/recovery busy (upper-bound overlap, not independent stall attribution) |
| 8,9,10,11 | Framebuffer store requests, VGA underflows, completed DOOM frames, latest frame clocks |
| 12,13 | Total/max fetch request wait cycles |
| 14,15 | Total/max data request wait cycles |
| 16,17 | Instruction cache hits/misses |
| 18 | CPU-valid overlap with active VGA arbitration ownership |
| 19,20,21 | Controller refresh count, ACT commands, column commands |
| 22,23 | Entries to ELF __mulsi3 and __udivsi3 (not all 64-bit/FP arithmetic) |
| 24 | CPU data requests |
| 25,26,27 | Latest frame retirements, fetch stalls, data stalls |
| 28..31 | Reserved zero |

Counters are unsigned 32-bit modulo counters; cycles wrap every 85.9 s.
Collect two snapshots less than 60 s apart. Subtract modulo 2^32. CPI is
Delta cycles / Delta retired; MIPS = 50/CPI. FPS = 50e6 * Delta frames /
Delta cycles; average fetch/data waits are Delta sums / Delta requests.
For one completed frame use 50e6 / frame_cycles and frame_cycles /
frame_retired. Avoid sampling during the opening melt; measure at least ten
frames for stable FPS, using successive snapshots within the wrap interval.
Live simulation PERF lines occur on the mailbox update edge: frame-latched
slots 10/11/25..27 lag that printed edge by one clock; use consecutive global
counter differences for analysis. Hardware frozen snapshots do not have this
sampling issue after that single clock has elapsed.

Raw SDRAM row-hit distributions, isolated refresh causality and CPU ALU
critical-path profiling are not provided by these counters. Existing
controller behavior fixes row reuse at zero between requests; request waits
include arbitration, controller, response registration and cache lookup.
Branch/ALU instructions retain the unchanged multicycle DECODE/EXEC path;
loads/stores also pay the existing GAP cycle. A hardware M-extension or
compiler/arithmetic changes should be a subsequent measured optimization,
not combined into this cache experiment.

## Qualified candidates, physical results pending

- `candidates/doom_icache4k_D7000001_20261114T082224Z.sof`
- `candidates/doom_profile_uncached_D7000001_20261114T082224Z.sof`
- Compatible unchanged ELF: `artifacts/doom-rv32i.elf`

Both compiled with positive setup/hold slack (+2.069/+0.215 ns worst across
reported corners), no ignored critical assignments, and no new critical
unconstrained paths. See `PROFILING.md` for simulation results and limits,
`HARDWARE_TEST.md` for exact manual commands. Cached later frames measured
1.428 s/frame in simulation; physical improvement and >=1 FPS remain
unverified. No FPGA programming or Flash write was performed.
