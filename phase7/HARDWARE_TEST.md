# Phase 7 hardware A/B gate — manual actions only

The original physically working image is preserved in `phase7/baseline`.
No Phase 7 image has been programmed by the agent. Do not change the 50 MHz
clock or SDRAM timing. No Flash writes are required or authorized.

1. Program the counters-only `doom_profile_uncached_D7000001_*.sof` candidate.
2. Upload the unchanged ELF/IWAD with the corrected Phase 6 uploader.
3. Wait for E1M1 and the opening melt to finish. Collect profiling snapshots
   less than 60 seconds apart, spanning at least ten completed engine frames.
4. Program `doom_icache4k_D7000001_*.sof`, upload the exact same files, and
   repeat from the same idle E1M1 position. Do not press movement keys while
   measuring the comparison. Test keys separately afterward.
5. Report FPS, CPI, fetch/data wait fractions, cache hits/misses, underflows,
   and any visible artifacts or input problems. Keep all raw snapshots.

From repository root, explicitly choose the file to program (do not use an
ambiguous wildcard in the programmer):

```sh
export QUARTUS_64BIT=0
Q=<quartus-bin>
ls phase7/candidates/*.sof
SOF=phase7/candidates/doom_icache4k_D7000001_20261114T082224Z.sof
# Counters-only baseline instead:
# SOF=phase7/candidates/doom_profile_uncached_D7000001_20261114T082224Z.sof
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload \
  --elf phase7/artifacts/doom-rv32i.elf \
  --wad phase6/assets/doom1.wad \
  --cable 'USB-Blaster [1-1]' \
  --device '@1: EP2C(15|20) (0x020B30DD)'
# Only after E1M1 is running; this writes diagnostic source selectors:
"$Q/quartus_stp" -t phase7/tools/profile.tcl \
  'USB-Blaster [1-1]' '@1: EP2C(15|20) (0x020B30DD)' \
  > phase7/reports/hardware-snapshot-A.txt
# Repeat later to hardware-snapshot-B.txt; use the modulo-delta formulas
# documented in README.md. Save separate files for each variant.
```

ACK/CRC success is necessary but does not establish gameplay performance.
Confirm the real room, pistol, HUD and keyboard action on VGA. Abort and
manually restore the preserved baseline SOF on corruption, traps or resets.
The cache test changes no WAD/heap/stack/framebuffer memory allocation.
A measured physical FPS improvement, especially >=1 FPS, remains a hardware
test outcome and is not asserted from simulation or timing closure.

Calculate the saved counter interval without accessing hardware:

```sh
python3 phase7/tools/analyze_hardware.py \
  phase7/reports/hardware-snapshot-A.txt phase7/reports/hardware-snapshot-B.txt
```

Snapshots must come from the same uninterrupted run and be less than 60 s
apart. For the slow baseline, collect several such intervals if ten frames
do not fit in one. Sum cycle/frame deltas across those intervals. Max-wait
counters are lifetime maxima, including SDRAM power-up; differences of maxima
are not interval maxima. Refresh/VGA overlaps must not be summed as causal
stall fractions. Record room/keys/game state alongside the raw snapshots.
