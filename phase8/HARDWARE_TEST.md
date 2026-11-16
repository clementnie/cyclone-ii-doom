# Phase 8 physical validation (manual only)

No programming, upload, board reset or Flash write was performed by the agent.
Only proceed with a candidate listed in `candidates/SHA256SUMS` after release
checks pass. Use the exact same ELF, IWAD, E1M1 scene and no-key interval for
both Phase 7 and Phase 8. Wait for the opening melt to finish before sampling.

From `<checkout>`:

```sh
python3 phase8/tools/check_release.py
(cd phase8/candidates && sha256sum -c SHA256SUMS)
export QUARTUS_64BIT=0
Q=<quartus-bin>
SOF=PHASE8_CANDIDATE_PATH
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload \
  --elf phase8/artifacts/doom-rv32i.elf --wad phase6/assets/doom1.wad \
  --cable 'USB-Blaster [1-1]' --device '@1: EP2C(15|20) (0x020B30DD)'
```

Require successful packet ACK/readback CRC verification and entry handoff.
Then confirm the actual E1M1 room, pistol and HUD, and test movement/turn/fire.
The loader and memory map are unchanged. Never run the diagnostic profiler
while the ROM loader is still active: profiling commands are for the running
engine. Phase 8 has a D8000001 diagnostic signature.

```sh
"$Q/quartus_stp" -t phase8/tools/profile.tcl \
  'USB-Blaster [1-1]' '@1: EP2C(15|20) (0x020B30DD)' \
  > phase8/reports/hardware-A.txt
sleep 20
"$Q/quartus_stp" -t phase8/tools/profile.tcl \
  'USB-Blaster [1-1]' '@1: EP2C(15|20) (0x020B30DD)' \
  > phase8/reports/hardware-B.txt
python3 phase8/tools/analyze_hardware.py \
  phase8/reports/hardware-A.txt phase8/reports/hardware-B.txt
```

Profiling writes only mailbox diagnostic commands; snapshots are atomic and
do not pause the CPU or generate SDRAM traffic. Keep consecutive snapshots
under 60 seconds, without a reset between them. Require zero underflows and
no visible corruption; record the interval, frame count, FPS, CPI and stalls.
Repeat three intervals for both images. FPS = 50e6 * delta_frames / delta_cycles;
CPI = delta_cycles / delta_retired. The earlier physical Phase 7 interval is
0.815153 FPS, but a fresh comparison in the same scene is preferable. Slots
28/29 additionally report SDRAM row hits/misses, including VGA transactions.

Restore the exact working Phase 7 release:

```sh
SOF=phase8/baseline/doom_icache4k_D7000001_20261114T082224Z.sof
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload \
  --elf phase8/baseline/doom-rv32i.elf --wad phase6/assets/doom1.wad \
  --cable 'USB-Blaster [1-1]' --device '@1: EP2C(15|20) (0x020B30DD)'
# Use phase7/tools/profile.tcl for snapshots on the restored D7000001 image.
```

The original Phase 6 image remains at
`phase6/candidates/cyclone_ii_doom_D6000001_20261114T073201Z_d51a123a8b48.sof`.
Its uploader is unchanged; it does not expose the Phase 7/8 profiling commands.
