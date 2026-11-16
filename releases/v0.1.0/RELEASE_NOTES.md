# v0.1.0 — DOOM on Cyclone II

First public release: custom RV32IM computer on EP2C20F484C7 at 50 MHz,
8 MiB SDRAM, split 2 KiB I/D caches, indexed 320×200 DOOM, VGA and PS/2.

The unchanged Phase 9 SOF/ELF pair is the latest physically working configuration
identified in the project. User-captured physical logs yield 2.446766 FPS across
118 presentation frames and zero underflows. Publication reproduced counter
arithmetic and source/checksum gates; it did not program the FPGA or repeat the
physical run. Historical fit: 14,732 LEs, 52 M4Ks, +2.069/+0.215 ns setup/hold.

Assets: the Phase 9 SOF, matching `doom-rv32im.elf`, complete corresponding source
archive, license/attribution archive, programming/rollback guide, manifest and
SHA256SUMS. The source archive also preserves the Phase 7 rollback pair.
No IWAD is included. Supply your own authorized compatible IWAD separately.

Download all assets, verify `sha256sum -c SHA256SUMS`, extract the source archive
and follow `PROGRAMMING.md`. The guide uses the identical binaries retained at
their phase paths. SRAM programming is volatile; no Flash operation is needed.

Known limits: approximately 2.45 FPS, no audio/network/OS, limited keyboard/menu
mapping, polling palette updates and full M4K utilization. Phase 10 is experimental:
its original SOF failed physical CRC and its hotfix awaits physical validation.
The old approximately 5.41 FPS startup simulation is not a hardware benchmark.
