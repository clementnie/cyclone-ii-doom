# Physical first-boot gate

The user reports successfully programming this candidate onto the board.
The agent has not programmed, reset or uploaded to it. No Flash write has
been performed. See [ISSP_HOTFIX.md](ISSP_HOTFIX.md) before uploading.
The existing board was found read-only as:

- Cable: `USB-Blaster [1-1]`
- Device: `@1: EP2C(15|20) (0x020B30DD)`
- Quartus II 13.0.1 SP1, 32-bit

The full-SoC simulation, all RTL regressions and final timing checks have
passed. The candidate is identified by `candidates/LATEST` after assembly.
This document is not a physical success claim.
The user must run the commands below and report the result. Keep the
previously verified SOFs available for manual rollback.

## Manual volatile programming and upload

Run from `<checkout>`. The first command programs SRAM
configuration only; run it yourself when ready. Do not use a `.pof` or Flash
programming mode. Normal JTAG chain order is FPGA at index 1.

```sh
export QUARTUS_64BIT=0
Q=<quartus-bin>
SOF="phase6/candidates/$(cat phase6/candidates/LATEST)"
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload \
  --cable 'USB-Blaster [1-1]' \
  --device '@1: EP2C(15|20) (0x020B30DD)'
```

Use `python3 phase6/tools/acquire_iwad.py` first if `assets/doom1.wad` is
missing. The upload command revalidates ELF/IWAD, emits a manifest, starts
one Quartus ISSP session, verifies each ACK and each region readback CRC,
and requests entry handoff only after all regions are verified. It does
not program the FPGA. Do not upload to the older Phase 4B image: it has no
DOOM6 ISSP instance, and the utility will refuse it.

If the USB path changes, enumerate without programming:

```sh
"$Q/jtagconfig"
"$Q/quartus_stp" -t phase6/tools/list_jtag.tcl
```

An upload is 92,693 packets plus initial synchronization. The final WAD
END/readback-CRC can pause progress output for many seconds. The host
per-command deadline is 180 s. The engine checks the IWAD CRC again after
handoff, so the diagnostic screen may persist before the first game image.
The model needed about 67 s after handoff to submit its first frame and
about 4 s for a later startup-frame interval, before accounting for real
host transfer overhead. These are model measurements, not physical timings.
Do not assume a blank/unchanged screen immediately implies failure.

## What to observe and report

Before upload, the diagnostic screen's RAM-result field shows D6000001
(ready), or E6000008 after five idle seconds; starting the uploader resets
this idle timeout. During transfer it shows D6000002/3/4. D6000005 means
verified entry handoff, not proof that the engine has rendered anything.
LEDR0 indicates a stopped CPU trap. An engine fatal exit is shown in the
existing diagnostic error field as E5000000|status, if the diagnostic VGA
is still selected.

After engine initialization, VGA should switch to the real E1M1 room,
pistol and status bar. There may be a brief initial melt/garbage transition.
Audio is disabled. Try arrows to move/turn, Ctrl to fire and Space to use.
Esc opens/closes the menu; Enter is not implemented in this candidate.
E1M1 starts directly to avoid requiring menu selection.

Report upload completion/error, the last displayed D6/E6/E5 code, LEDR0,
what VGA shows, and whether movement/turn/fire respond. A photograph and
approximate time from handoff to visible frame are useful. Physical FPS,
input latency, SDRAM robustness, palette update behavior and ISSP transfer
rate remain unmeasured until this test. No playable-hardware claim follows
from simulation.

For any interrupted transfer, press KEY0 and rerun the complete upload.
Reset discards the session/descriptor and returns to ROM; SDRAM retention
is never trusted as a verified image. Manual rollback uses the same
volatile programmer command with the chosen known-good SOF instead.

Qualified release: `cyclone_ii_doom_D6000001_20261114T073201Z_d51a123a8b48.sof`.
The adjacent `.sha256` file records its integrity. The prior SOFs and source
checkpoints are preserved. The user has programmed the image; read-only physical discovery of its
OOM6 480/96 mailbox passes after the host correction. Actual upload and
engine execution on hardware await authorization and observed results.
