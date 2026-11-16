# Phase 8: open-row SDRAM, release freeze

The only architectural change keeps one SDRAM row open per bank. A matching
request goes directly to its two BL1 column transfers; a different row closes
only that bank before ACT. Refresh first closes all banks, waits tRP, and
retains the original refresh interval and recovery. The original conservative
column, capture and write-recovery waits remain unchanged. No burst-mode,
CPU, cache, compiler, renderer, ELF, bootloader or uploader change is included.

The measured physical Phase 7 release is preserved at e5c905b in `baseline/`;
original checkpoints 35095c6 and 0cff578 remain intact. Its 8-frame interval
is 0.815153 FPS, CPI 15.6194, 22.19% fetch stalls and 56.24% data stalls.
Removing all data stalls alone has a theoretical ceiling of 1.863 FPS for
that same instruction workload. Removing both fetch/data stalls gives 3.780
FPS; these are Amdahl bounds, not achievable performance predictions.

The actual Phase 7 fit consumes **52/52 M4K blocks**, despite 85% logical
memory-bit utilization. The CPU is blocking FETCH/DECODE/EXEC, plus MEMORY
and GAP for data operations. An I-cache hit still takes two lookup/wait
cycles. Software multiplication/division, register reads and execution
remain unchanged. Framebuffer presentation packs four byte loads per store.
The closed-page controller imposed ACT + two columns + PRE on every word,
including roughly 0.95 million VGA word reads per second. Open rows reduce
that shared bandwidth cost without adding M4K storage. Four-video/one-CPU
arbitration, fairness, pin assignments and timing constraints are unchanged.

The independent delayed SDRAM test uses the same deterministic accesses:

| Controller | 2,048 sequential/bank-interleaved reads | 16,109 mixed accesses, including initialization |
|---|---:|---:|
| Closed row | 41,386 clocks | 345,529 clocks |
| Open row | 25,808 clocks | 235,474 clocks |

These are controller service cycles, not CPU cycles or DOOM FPS. Sequential
service improves 1.604x; mixed service improves 1.467x. Random byte/halfword
writes, row/bank switching, held valid, bounds, refresh and reset pass.
`reports/comparison.json` records full SoC frame intervals for both variants:
same ELF/IWAD, 4 KiB I-cache, ROM upload/CRC and eight real engine frames.
DOOM uses elapsed hardware time, so frame numbers alone do not guarantee
identical instruction workloads; simulation ratios are not physical FPS.

Quartus 13.0 SP1 32-bit fits 13,993/18,752 LEs (75%), 52/52 M4Ks and 203,904
logical memory bits. Reports include both corners and external SDRAM paths.
The release gate requires positive setup/hold slack and unchanged constraints.
Only the forwarded DRAM_CLK reference remains in the unconstrained path
report, as in Phase 7; SDRAM data/control are constrained. Asynchronous inputs
and VGA retain the original explicit synchronization/constraint treatment.

JTAG profiling signature is D8000001, with the same 480/96 DOOM6 mailbox
(wire identity OOM6). Slots 0..27 retain Phase 7 meanings; 28/29 count accepted
row-hit/row-miss requests (including VGA); 30/31 remain zero. Row hits are
not cache hits. Use the Phase 8 profiler only after engine handoff. Counters
are 32-bit modulo; snapshot intervals must be less than 60 seconds.

Reproduce from the repository root:

```sh
make -C phase8 build/full0/Vfull_top build/full1/Vfull_top
phase8/build/full0/Vfull_top phase6/build/upload.hex 12000000000 8 closed > phase8/reports/closed-boot.log
phase8/build/full1/Vfull_top phase6/build/upload.hex 12000000000 8 openrow > phase8/reports/openrow-boot.log
python3 phase8/tools/analyze.py
python3 phase8/tools/regress.py
make -C phase4 test regression
sh phase8/quartus/build.sh
python3 phase8/tools/check_release.py
sh phase8/quartus/assemble.sh
```

Source integrity hashes are in `reports/build-sources.json`; asset hashes
include the legal IWAD and exact unchanged ELF. `sim/tb_sdram.sv` selects
OPEN_PAGE=0/1 for the controller microbenchmark. Focused I-cache, counters,
ISSP uploader/CRC and adversarial ROM-loader checks accompany integrated
CPU/SDRAM/VGA/keyboard regressions. Full simulation observes additional
shadow-cache locality models without changing execution; these were already
running when the user ordered release freeze. No subsequent architecture
experiment was started.

Remaining bottlenecks: blocking CPU; uncached data; two separately issued x16
column operations per word; VGA arbitration; instruction misses; software
arithmetic; framebuffer copy. No claims of 3, 10 or 30 FPS. Physical Phase 8
performance is pending. See `HARDWARE_TEST.md` for exact commands and restore.
