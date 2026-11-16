# Manual FPGA validation and rollback

Use the CRC hotfix candidate below. The original Phase 10 SOF failed physical
ELF CRC readback. See [HOTFIX.md](HOTFIX.md) for the exact diagnosis and evidence.
The corrected SOF has not been programmed by the agent.

Run from `<checkout>`. These commands are for the user;
the agent has not programmed the board or written Flash. Use the matching
Phase 10 ELF and SOF. The loader wire identity remains OOM6/DOOM6; the
performance signature is **DA000001**.

## Program SRAM and upload

```sh
cd <checkout>
python3 phase10/tools/check_release.py
(cd phase10/candidates && sha256sum -c doom_chromatix_160x100_block32_crcfix_DA000001_20261114T212632Z.sof.sha256)
(cd phase10/artifacts && sha256sum -c SHA256SUMS)
export QUARTUS_64BIT=0
Q=<quartus-bin>
mkdir -p phase10/build
SOF=phase10/candidates/doom_chromatix_160x100_block32_crcfix_DA000001_20261114T212632Z.sof
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload \
 --elf phase10/artifacts/doom-rv32im.elf --wad phase6/assets/doom1.wad \
 --out phase10/build/hardware-upload-crcfix.hex \
 --cable 'USB-Blaster [1-1]' --device '@1: EP2C(15|20) (0x020B30DD)'
```

Require successful packet ACKs, segment/WAD CRCs and engine handoff. Let the
opening melt finish and the pistol rise. Confirm recognizable E1M1, ceiling,
walls, floor, sprites, HUD, palette flashes, menu and a subsequent screen wipe.
Test arrows, Ctrl/fire, Space/use and Esc/menu. Watch for tearing, stale pixels,
SDRAM corruption, traps or underflows. The sampled image is intentionally
blockier at 160x100. The captured simulation image is
`phase10/artifacts/phase10-vga.png`.

## Measure actual gameplay

Do not profile during the loader or the opening wipe. Use the same idle E1M1
view as Phase 9, then a separate movement/shooting interval. Capture at least
three 20-second pairs, each less than 60 seconds apart, without reset.

```sh
"$Q/quartus_stp" -t phase10/tools/profile.tcl \
 'USB-Blaster [1-1]' '@1: EP2C(15|20) (0x020B30DD)' > phase10/reports/hardware-A.txt
sleep 20
"$Q/quartus_stp" -t phase10/tools/profile.tcl \
 'USB-Blaster [1-1]' '@1: EP2C(15|20) (0x020B30DD)' > phase10/reports/hardware-B.txt
python3 phase10/tools/analyze_hardware.py \
 phase10/reports/hardware-A.txt phase10/reports/hardware-B.txt
```

`delta = (after-before) & 0xffffffff` for each counter.
`FPS = 50000000 * delta(engine_frames) / delta(cycles)`.
`CPI = delta(cycles) / delta(retired)`.
Require `delta(underflows)=0`, with no visual faults or traps. Presentation
frames include intermediate wipe frames, which is why measurements must start
after the wipe. `0x1000400c` separately counts real completed 3D view renders;
it is used by the simulator and is not an extra JTAG performance register.
Stall counters are overlapping request-wait observations; do not add their
fractions into a CPI decomposition. Cache hit/miss events count CPU read
requests, not SDRAM halfwords or every word of a line refill. SDRAM read/word
counters at the arbiter also include CPU refill requests served from the block
buffers; column-command counts reveal physical SDRAM commands. The two legacy
fixed-PC counters remain unsuitable for the relocated/LTO ELF.

The short simulation's approximately 5.41 FPS does not establish physical
performance or the 20FPS target. Report the measured hardware result even if
it falls well short. Keep raw counter logs and scene notes.

## Resolution and compiler A/B tests

All these ELFs use this same Phase 10 SOF. Repeat the uploader command with
one of the following `--elf` paths, then wait for the wipe and repeat the same
scene/interval. The default 160x100 O2 ELF is the only bounded DOOM-boot-tested
variant; all alternatives are experimental and were built with focused shared
renderer/video checks.

| ELF | Rendering | Compiler |
| --- | --- | --- |
| `phase10/artifacts/doom-160x100-rv32im.elf` | 160x100 | O2 + LTO, default |
| `phase10/artifacts/doom-160x120-rv32im.elf` | 160x120 | O2 + LTO |
| `phase10/artifacts/doom-160x200-rv32im.elf` | 160x200 | O2 + LTO |
| `phase10/artifacts/doom-320x200-rv32im.elf` | 320x200 | O2 + LTO |
| `phase10/artifacts/doom-160x100-O3-rv32im.elf` | 160x100 | O3 + LTO |
| `phase10/artifacts/doom-160x100-Os-rv32im.elf` | 160x100 | Os + LTO |

Reprogram this SOF before changing variants so the MMIO render counter, display
mode and caches all start clean. Do not use an old RV32I bitstream with RV32IM
firmware. The Phase 10 ELF additionally requires its new resolution register.

## Restore the physically working Phase 9 release

```sh
SOF=phase9/candidates/doom_pipeline_im_split2k_D9000001_20261114T201849Z.sof
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload \
 --elf phase9/artifacts/doom-rv32im.elf --wad phase6/assets/doom1.wad \
 --out phase10/build/rollback-phase9-upload.hex \
 --cable 'USB-Blaster [1-1]' --device '@1: EP2C(15|20) (0x020B30DD)'
```

Use `phase9/tools/profile.tcl` after rollback; its signature is D9000001.
The recoverable source baseline is Git branch `phase10-prechange-c0533ec`.
No checkout is necessary to restore the preserved SOF/ELF. Phase 6–8 releases
are also untouched.
