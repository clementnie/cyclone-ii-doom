# Manual physical test and rollback

From `<checkout>`; do not write Flash. The agent has not
programmed the board. Use the exact candidate path listed in `candidates/`.

```sh
python3 phase9/tools/check_release.py
(cd phase9/candidates && sha256sum -c SHA256SUMS)
export QUARTUS_64BIT=0
Q=<quartus-bin>
SOF=phase9/candidates/doom_pipeline_im_split2k_D9000001_20261114T201849Z.sof
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload \
 --elf phase9/artifacts/doom-rv32im.elf --wad phase6/assets/doom1.wad \
 --out phase9/build/hardware-upload.hex \
 --cable 'USB-Blaster [1-1]' --device '@1: EP2C(15|20) (0x020B30DD)'
```

Require successful ACK/CRC and engine handoff. Confirm E1M1 room, pistol and
HUD, then movement, turning and fire. Wait for the opening melt to finish.
Capture three pairs of snapshots, each under 60 seconds apart. Require zero
underflows and no visual corruption. Signature is D9000001; mailbox wire
identity remains OOM6/DOOM6 for the existing uploader.

```sh
"$Q/quartus_stp" -t phase9/tools/profile.tcl \
 'USB-Blaster [1-1]' '@1: EP2C(15|20) (0x020B30DD)' > phase9/reports/hardware-A.txt
sleep 20
"$Q/quartus_stp" -t phase9/tools/profile.tcl \
 'USB-Blaster [1-1]' '@1: EP2C(15|20) (0x020B30DD)' > phase9/reports/hardware-B.txt
python3 phase9/tools/analyze_hardware.py phase9/reports/hardware-A.txt phase9/reports/hardware-B.txt
```

Do not use profiling commands during the ROM loader. FPS is
50e6*delta_frames/delta_cycles; CPI is delta_cycles/delta_retired. In Phase 9,
cache hit/miss events include I and D reads, unlike Phase 7/8. Fetch activity
can overlap execution; stall counters are request-wait observations, so the
old additive CPI stall decomposition no longer applies. Slots 22/23 retain
legacy fixed-PC matching hardware and are labeled legacy_pc22/23_matches;
they are not valid arithmetic call counters for the new ELF. Keep the same E1M1
scene and idle input interval for comparisons.

Restore the preserved working Phase 7 image and matching RV32I firmware:

```sh
SOF=phase8/baseline/doom_icache4k_D7000001_20261114T082224Z.sof
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload \
 --elf phase8/baseline/doom-rv32i.elf --wad phase6/assets/doom1.wad \
 --out phase9/build/rollback-upload.hex \
 --cable 'USB-Blaster [1-1]' --device '@1: EP2C(15|20) (0x020B30DD)'
```

Use `phase7/tools/profile.tcl` on restored Phase 7. Phase 9's RV32IM ELF
requires the new core and must not be uploaded to the old RV32I core.
Phase 6 and Phase 8 original images and sources remain untouched.
