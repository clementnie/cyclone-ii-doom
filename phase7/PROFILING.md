# Phase 7 findings

Physical baseline: user observes 5–10 seconds/frame (0.1–0.2 FPS) on the
preserved Phase 6 image. This is visual timing, not counter-derived FPS.
Phase 7 physical results are pending; no achieved physical speedup is claimed.

The baseline controller pays ACT + two x16 columns + PRE for every 32-bit
instruction, including repeated loop instructions. The RV32I core has no
fetch overlap: FETCH waits, DECODE registers operands, EXEC updates PC or
starts a data transfer, and loads/stores add GAP. Branches do not flush a
pipeline; they pay the next blocking fetch. The first tested optimization
is therefore instruction locality, not an ALU/register-file redesign.

The cached digital SoC executes the exact original ELF/IWAD from ROM upload
through eight actual engine frames and two VGA rasters with zero traps or
underflows. Its last interval (frame 7 to 8) measured:

| Measurement | Simulation result |
|---|---:|
| Frame clocks / seconds at 50 MHz | 71,400,000 / 1.428 |
| FPS for this interval | 0.700 |
| Retired instructions | 4,788,626 |
| CPI | 14.910 |
| Fetch wait mean | 3.736 clocks/request |
| Fetch wait share | 25.06% |
| Data wait mean | 47.43 clocks/request |
| Data wait share | 52.61% |
| Instruction cache hit rate | 96.16% |
| SDRAM read/write requests, includes VGA | 2,079,130 / 255,589 |
| Framebuffer stores | 16,000 words |
| __mulsi3 / __udivsi3 entries | 16,608 / 1,363 |

This is a short startup/E1M1 interval, not a steady gameplay benchmark. The
1 FPS target has not been established, including in this measured interval.
The uncached final interval was 199,085,416 clocks (3.982 s, 0.251 model
FPS), CPI 46.53 and mean fetch wait 41.09 clocks, with 88.31% fetch waits.
The 2.79x ratio to the cached final interval is **not** a controlled steady
renderer speedup: the uncached trace ends on its third startup/melt frame,
whereas the cached trace has progressed to eight frames. The valid result
is the lower measured fetch cost and a passing, real-frame candidate.
`reports/comparison.json` contains uncached and cached counter deltas; early
melt intervals have different work and must not be compared as identical
renderer workloads. Physical A/B snapshots are the next acceptance gate.

After caching, data waits are the largest measured share. VGA DMA shares
the same controller: 80 words per source row, 200 rows per raster (~0.95 M
reads/s). The snapshot also counts CPU-valid overlap with video ownership;
this is not an independent additive delay. Burst/open-row video transfers
or a carefully budgeted data-read cache are candidates for a later measured
change. Raw controller latency histograms, random/sequential microbenchmarks
and isolated refresh attribution remain unimplemented; CPU-facing waits
already include the controller, arbitration and response pipeline.

DOOM's FixedMul uses signed 64-bit multiply shifted by 16; FixedDiv uses a
64-bit numerator and software division with overflow checks. The counters
currently count only the named 32-bit helpers; they are not a complete count
or cycle attribution of 64-bit and floating-point support. Disassembly of
__mulsi3 shows seven loop instructions per active multiplier bit, up to 32
iterations, plus entry/return. Hardware multiply could remove substantial
instruction work, but requires a compatible ISA/ELF or port change and is
not combined with this cache release. Compiler flags remain -Os/RV32I;
changing code size may change direct-map cache conflicts, so -O2 is not
assumed to be faster without a separate experiment.

Framebuffer presentation still packs four byte loads into each 32-bit store,
copying 64,000 bytes/frame. Allocator alignment permits a later aligned-word
copy optimization, but this release retains the working ELF. Avoiding the
entire copy requires proving buffer ownership/renderer compatibility. WAD
I/O remains random-access reads from the one SDRAM IWAD plus selected zone
caches; no complete second WAD copy is introduced. Rendering resolution,
textures, sprites, gameplay and audio-disabled configuration are unchanged.

The final cached fit uses 13,703 logic elements (73%) and 203,904 memory bits
(85%). The profiling-only fit uses 11,149 elements (59%) and the original
159,872 memory bits (67%). Both retain positive setup/hold slack and the
original external SDRAM constraints. Profiling uses FPGA area but no CPU
polling or SDRAM transactions. Lifetime wait maxima include power-up and
must not be labeled gameplay-only maxima.
