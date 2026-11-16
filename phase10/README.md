# Phase 10 CRC hotfix candidate

Default: 160x100 selective rendering, RV32IM O2/LTO, 32-byte split-cache lines,
four SDRAM block buffers, Phase 9 BL1 read cadence and consecutive halfword writes.
The original physical candidate failed ELF readback CRC. The controller hotfix
and exact evidence are in [HOTFIX.md](HOTFIX.md); physical confirmation of the
new SOF remains pending user programming.
The CPU architecture and 50MHz clocks remain Phase 9's. Pre-change checkpoint:
`phase10-prechange-c0533ec` (`c0533ec`). All Phase 6–9 releases are preserved.

**20–30 physical gameplay FPS is not established.** One bounded ROM-loader /
DOOM run completed three real 3D renders, twelve presentations (including the
opening wipe), and two raster captures with zero underflows. The last two
startup gameplay presentation intervals took 9239972 and 9239996 clocks,
about **5.41 simulated FPS**. This is neither a long timedemo nor a physical
measurement. Do not compare it directly with a differently measured hardware
scene. The artifact is a candidate for physical testing, not a target-FPS claim.

Final Quartus 13.0 SP1 EP2C20 fit: **13529/18752 LEs, 52/52 M4Ks**, eight
9-bit multiplier elements, one PLL. Worst setup/hold slack **+2.069/+0.215ns**;
slow/fast setup, hold, recovery, removal and constrained SDRAM paths pass.
Pin assignments and SDC are unchanged. The optional 120-row output uses an
exact scanline accumulator; the failed combinational-divider attempt is kept
under `reports/attempts/` for traceability. VGA memories use explicit synchronous
reads so Quartus maps them into M4Ks. No timing constraints were weakened.

## What changed

- Low-detail geometry renders 160 columns. Row selection occurs before column
  pixel generation and plane setup, including walls, sky, sprites, translations
  and fuzz. Main-screen UI patches skip unused samples; backing buffers remain
  complete. Wipes reconstruct missing rows before capture.
- Present directly from I_VideoBuffer, removing the redundant full-screen copy
  and unused 256000-byte output allocation. Pack selected pixels into 16000-byte
  indexed frames; VGA scales them into the original 640x400 letterbox.
- Reuse the existing 2KiB I + 2KiB D data RAM for 32-byte lines. Reduced tag depth
  funds four 32-byte buffers without increasing total M4Ks. Stores invalidate
  matching tags in both banks; writes remain ordered, synchronous write-through.
- Sixteen isolated BL1/CL2 SDRAM READ commands fill a block using Phase 9
  WAIT/CAPTURE spacing. Refresh starts 80 clocks earlier to reserve the longer
  refill while retaining the existing deadline. FPGA memory, MMIO and loader
  validation retain their contracts.
- Adapt ChromatiX's 32-bit FixedDiv with defined unsigned-magnitude saturation,
  including INT_MIN. Default Clang O2/LTO and O3/Os alternatives are available.
  No RISC-V GCC was installed; compiler alternatives have no measured FPS ranking.

[RESEARCH.md](RESEARCH.md) identifies inspected commits, adaptations and licenses.
[HARDWARE_TEST.md](HARDWARE_TEST.md) contains programming, upload, profiling and
Phase 9 rollback commands. The board has not been programmed by the agent.

## Verification and limits

`reports/final-verification.log` records the pre-hotfix verification: 507 CPU retirement states,
16 traps, 1024 M-operation vectors, cache line/conflict/coherence/reset/error
checks, 16109 randomized SDRAM transactions, all four pixel output modes, a
three-frame integrated pixel oracle, keyboard and MMIO regressions. Native
checks compare 1080 drawer cases, shifted views and fuzz against the preserved
renderer/oracles, 90 UI patch cases, and one million FixedDiv edge/random pairs.

The single historical DOOM boot used the final default ELF and predates this
controller hotfix. The hotfix has a separate complete ROM upload/CRC simulation
and integrated pixel test; gameplay was not resimulated. That historical simulation also predates the
behavior-preserving RAM inference cleanup and the optional 120-row scaler fix;
it was not repeated. Final all-mode and integrated pixel tests cover those RTL
changes. The precise scope is recorded in `reports/boot-scope.json`. Inspect
`artifacts/phase10-vga.png`: this is actual engine E1M1 output, not a test pattern.
Movement, shooting, extended gameplay, alternate ELFs and physical SDRAM margin
still need board testing.

Controller microbenchmark after the hotfix: 2048 sequential reads take 25801
clocks; the mixed workload takes 627419 clocks over 16109 requests. The original
pipelined candidate took 9924/246818 clocks but failed physical upload. This
hotfix deliberately restores the verified read cadence; previous performance
claims and boot measurements do not characterize the new controller.

## Build

From repository root, with the existing simulator installation in
`/tmp/phase9-tools` and Quartus in the paths recorded in the scripts:

```sh
python3 phase10/build.py
sh phase10/tools/verify.sh
make -C phase10 build/full1/Vfull_top
llvm-nm -n phase10/artifacts/doom-rv32im.elf > phase10/build/symbols.txt
python3 phase6/tools/upload.py --elf phase10/artifacts/doom-rv32im.elf --out phase10/build/upload.hex
# One bounded real-engine run; do not repeat during routine development:
timeout 1200 phase10/build/full1/Vfull_top phase10/build/upload.hex 4000000000 3 phase10 > phase10/reports/phase10-boot.log 2>&1
python3 phase10/tools/check_release.py snapshot
sh phase10/quartus/build.sh
python3 phase10/tools/check_release.py
python3 phase10/tools/test_upload_hotfix.py
python3 phase10/tools/test_upload_integrated.py
sh phase10/quartus/assemble_hotfix.sh
```

Build alternatives with `python3 phase10/tools/build_variants.py`; it restores
160x100 O2 as the default on completion. `DOOM_ROWS=120` or `200` selects a
row count. `DOOM_FULL=1 DOOM_ROWS=200` selects 320x200. `DOOM_OPT=-O3` or `-Os`
selects compiler optimization. All variants use the same Phase 10 SOF. Only the
default ELF has the bounded integrated DOOM boot result; alternatives passed
build plus the shared drawer/output-mode tests and require physical validation.

## Remaining bottlenecks

The interlocked fetch/operand/execute core and synchronous hit/handshake latency
remain substantial. A short observed gameplay interval still retired about
648000 instructions for 9.24M clocks. At 20FPS the entire budget is 2.5M clocks:
that instruction volume would require an average below 3.86 CPI. This candidate
does not approach that CPI. More cache capacity cannot remove that execution
floor. Small byte stores, view/span setup, shared memory arbitration and cache
refill handshakes remain; LTO's larger code may hurt the 2KiB instruction cache.
The O2/O3/Os variants allow measuring that tradeoff on the board. A further
major gain requires reducing those costs, not interpreting peak SDRAM bandwidth
as achieved game throughput.
