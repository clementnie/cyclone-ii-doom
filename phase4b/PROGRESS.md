# Phase 4B: candidate ready for physical validation

Implemented and tested: 320x200 INDEX8 in SDRAM; 2x VGA scale with 40-line
letterboxes; programmable RGB444 palette; double line buffers; weighted
CPU/video arbitration; vblank buffer selection; CPU-rendered moving test
image; serialized PS/2 arrows; Escape diagnostic fallback; sticky underflow
counter. The existing SDRAM controller and original CPU/RAM files remain
unchanged. A CPU response register cuts the measured MMIO timing path.

| Evidence | Result |
| --- | --- |
| Complete CPU image data path | 3 frames / 1,260,000 pixels, zero underflows |
| DG callback executable in CPU simulation | 1 frame / 420,000 pixels, zero underflows |
| Palette/swap/late-DMA/error/reset scanout test | 2,100,000 reference pixels pass |
| Weighted arbitration, saturated modeled memory | CPU/display waits <=136/54 cycles |
| Actual controller under CPU image contention | Display request maximum 49 clocks |
| MMIO contract | 15 aligned/read-only/partial/fetch/served checks pass |
| Serialized keyboard/CPU/framebuffer | Up moves expected RGB pixel; Escape fallback/restore; heartbeat 4 |
| Legacy regression and SDRAM suites | Pass, preserved baseline sources |
| Useful simulated SDRAM client bandwidth | Video 3.810 + CPU 2.856 = 6.665 MB/s; not physical measurement |
| Quartus normal full flow | Pass, exact device, original hardware hook |
| Resource use | 6360 LEs, 41/52 M4Ks, 1 PLL |
| Worst slow/fast setup | +2.069/+3.559 ns |
| Worst slow/fast hold | +0.445/+0.215 ns |
| SDRAM in/out slow setup | +2.069/+3.257 ns |
| Unconstrained data/control paths | None; forwarded clock is its own generated reference |

Compiled but not physically verified: `candidates/cyclone_ii_framebuffer_D4B00001.sof`.
No programmer was run. `reference.png` is the generated expected first
image, not a hardware photograph. Follow `HARDWARE_TEST.md` and report the
physical result before advancing the framebuffer milestone. D1060001 and
D4000001 remain byte-identical; D4000001 hardware success is user-confirmed.

DOOM progress: all 81 selected engine/platform units compile as RV32I.
Relocatable footprint 325,554 text + 60,028 data + 243,709 BSS bytes. The linked
minimal DG test is 1,583 text + 4 data + 65,040 BSS bytes and passes the CPU
video path. The full executable link was attempted and fails on explicit
runtime/file/compiler helper dependencies in `reports/doom-engine-link.log`.
No fake libc or WAD substitutes are used to claim success. Startup/linker
layouts, seven-key mapping, wrap-aware timer, integer helpers and a bounded
ELF/CRC packer exist. The documented host-JTAG loader is not implemented.
Authorized WAD, heap/zone peak measurements, Enter input and SDRAM-code
palette-update timing remain incomplete. No engine launch, DOOM FPS or
physical playability is claimed. See `doom/README.md` and `doom/LOADING.md`.

Final input hashes bind the fitted image and functional checks to their
sources. Failed pre-response-pipeline timing is retained for transparency;
no timing constraint, pin assignment or hardware hook was weakened.
