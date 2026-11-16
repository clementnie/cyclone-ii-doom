# Source research and design decisions

Primary article: https://enjoy-digital.github.io/posts/chromatix-doom/
Source inspected locally: https://github.com/enjoy-digital/chromatix/tree/doom
Pinned head: `7c9ce97`. File hashes: `reports/chromatix-source-manifest.json`.
No unrelated FPGA DOOM implementation was investigated.

Relevant commits inspected with git log/show:

- `20c5d3d`: enables the existing 32-bit FixedDiv and displayed-column drawers.
  `doomgeneric/m_fixed.c` divides unsigned magnitudes, computes the fractional
  quotient with either a second 32-bit divide or 16 restoring steps, then
  restores sign. `r_draw.c` writes only the first pixel of a low-detail pair.
- `40c6422`: `r_draw.c`, `r_plane.c`, `f_wipe.c`, `doomgeneric.h` add next/previous
  displayed-row tables, skip plane setup for discarded rows, jump columns
  directly between displayed rows, sample fuzz from displayed neighbors,
  and reconstruct skipped rows before wipe capture.
- `02b27eb`: `chromatix/gateware/memory.py` fetches aligned 32-byte blocks and
  retains four round-robin copies. Registered tag lookup avoids a long hit
  path; stores reach memory and maintain buffered-copy coherence.
- `ec84bef`: `hal_lcd_line_half` combines selected bytes with word loads/stores.
- `463c5c5`, `21c3312`, `1fff3d4`: enlarge caches, exploit partially occupied
  memory primitives, then move frame storage into external memory to fund L2.
  These exact sizes and Gowin primitives do not transfer to Cyclone II.
- `firmware/doom/Makefile`, `sources.mak`, and `doc/DOOM.md`: O2, builtins, LTO
  and compiler-version experiments. ChromatiX's ranking of O2/O3/Os and its
  measured FPS are evidence about that system, not measurements of ours.

## Adaptation

Keep DOOM's 320x200 coordinate system and low-detail projection. The default
renders 160 columns and 100 selected rows. This avoids geometry/HUD scaling
changes associated with redefining SCREENWIDTH/SCREENHEIGHT. 160x120 and
160x200 trade more sampling for detail; full 320x200 is a comparison build.
VGA still displays the original 640x400 letterbox in a 640x480 raster.

Walls, sky, ordinary sprites and weapon sprites use the selective low-detail
column drawer. Translated sprites get the same row skipping. Floors/ceilings
skip before R_MapPlane setup. Fuzz uses displayed neighbors. Main-screen UI
patches (including flipped and translucent patches) skip before sampling;
secondary HUD/background buffers remain complete because later block copies
may use their contents at a different vertical origin. Standard menu, palette,
gamma, HUD and game/input logic remain. Wipe captures reconstruct skipped rows
across the entire screen, including the selectively drawn UI. Melt operates
on pairs of columns, preserving the sampled even column.

Remove I_FinishUpdate's intermediate frame copy and doomgeneric's unused
256000-byte output allocation. Pack even pixels with two aligned source word
loads per output word. Only 16000 bytes are presented at 160x100; the old path
copied 64000 bytes twice. These are byte counts, not FPS estimates.

Keep the 4KiB cache data array; change one-word lines into 32-byte lines.
Separate synchronous I/D tags allow stores to invalidate matching lines rather
than unrelated tags at the same index. Reduced tag depth and 896 fewer valid
bits pay for four 32-byte block buffers. There is no new L2 or enlarged cache.

SDRAM uses sixteen consecutive legal BL1 READ commands at CL2, not the PSRAM
protocol and not a changed mode register. This is a pipelined 32-byte command
burst, with four clocks from launch to the registered-input capture FSM.
Consecutive x16 writes shorten the original word-store sequence. Byte masks,
commit-before-ack, refresh, open rows, VGA arbitration, MMIO bypass and loader
transactions retain their contracts. No posted/dirty writes exist.

Native drawer/original comparisons and delayed command-model tests check these
contracts. The command model now accepts a READ each clock with a two-stage
address pipeline; an independent C++ model does the same in the boot harness.
The controller's refresh bound stays 740 clocks in the focused regression.

Compiler default is Clang RV32IM O2 with LTO, no strict aliasing, and wrapping
signed arithmetic. A RISC-V GCC is not installed. No claim of GCC or LTO speedup
on this machine is made. O3 and Os alternatives are built for physical A/B
measurements; code size alone cannot rank them. See compiler-variants.json.

## Attribution

DOOM-derived files retain their GPL-2.0-or-later notices. Selective drawers,
row tables and FixedDiv are adapted from the ChromatiX source above, by Florent
Kermarrec/Enjoy-Digital and its contributors. The platform table/packing ideas
also derive from its BSD-2-Clause platform layer. Both license texts are in
`licenses/`. The matching complete source consists of phase10's overrides,
phase4b/doom's preserved engine/includes/runtime, and phase5/vendor/compiler-rt
(with its existing notices). No Gowin primitive or LiteX infrastructure was
copied into the RTL.
