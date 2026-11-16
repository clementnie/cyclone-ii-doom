# Bare-metal RV32I doomgeneric work

Source is retained unmodified in `upstream/`, with GPL-2.0 and original
per-file notices. `UPSTREAM.md` records URL/archive digest and
`upstream/SOURCE_SHA256.json` pins each imported file. No WAD was imported.
The initial GitHub connector failed; the public source archive was downloaded
with approval. Reproduction needs no further download.

```sh
make -C phase4b/doom platform-test
python3 phase4b/doom/compile_engine.py
make -C phase4b platform-test
make -C phase4b/doom engine-link  # currently expected to fail: see report
```

`platform.c` implements all DG functions, including window-title no-op.
INDEX8 (CMAP256) avoids a full RGB conversion; gamma-corrected RGB entries
are converted to RGB444 palette values. It copies 64,000 bytes to the back
slot, uploads palette during vblank, and requests a vblank-only flip.
The scanline MMIO register bounds palette update timing. This palette path
is polling code, not a shadow palette with hardware atomic commit.
Timer accumulates 50 MHz cycle deltas with wrap-safe subtraction and keeps
sub-millisecond remainder. Poll at least every 85.9 seconds. Seven verified
PS/2 IDs map to arrows/fire/use/Escape. **Enter is not implemented in the
current keyboard decoder** and is an additional menu bring-up requirement.
Audio/multiplayer are disabled by upstream feature configuration.

The linked minimal platform test places its pixel and palette arrays in
SDRAM, invokes the real DG callbacks and then polls timer/input. A dedicated
CPU simulation compares all 420,000 pixels of a VGA frame against its
indexed gradient, with zero underflows. This validates the platform video
path, not the DOOM engine or its heap/file system.

All 81 selected engine/platform translation units compile for RV32I/ILP32.
`build/doom-engine.rv32i.o` is a **relocatable object**, not an executable.
Its measured text/data/BSS are 325,554 / 60,028 / 243,709 bytes. The full
executable link was attempted: `../reports/doom-engine-link.log` lists each
missing symbol; `unresolved.txt` records all dependencies before supplied
integer helpers. Missing pieces include libc allocation, strings, formatted
I/O and memory-backed files, plus compiler-rt soft-float and 64-bit helpers.
`include/` provides freestanding *declarations*, not a pretend libc.
`integer_runtime.c` implements 32-bit multiply/divide/remainder; 100,000
native signed/unsigned reference cases pass. No M/F/D instructions are
permitted by the compiler target. Software floating point is still needed.

Startup and linker layouts exist for both ROM platform test and SDRAM engine.
Heap/stack/asset plan and concrete host-assisted loading protocol are in
`LOADING.md`. The loader and C runtime are incomplete. Upstream's 6 MiB
zone is incompatible with a large resident WAD; the proposed `-mb 2` needs
actual peak allocation and level testing. Upstream also allocates four bytes
per presentation pixel even in indexed mode, an identified optimization
opportunity; it is not silently patched here.

No DOOM engine has been launched, no WAD was loaded and no FPS or physical
playability is claimed. Further software work is independent of the pending
physical framebuffer validation, but this iteration stops at that hardware
gate with the full compile/link evidence preserved.

`pack_image.py ENGINE.ELF OUTDIR [--wad AUTHORIZED.WAD]` prepares bounded
ELF32 segments and CRC32 metadata for that future loader; it rejects overlap
with framebuffer, WAD and stack reservations. It does not access hardware.

The palette loop is validated with platform code executing from ROM. A full
engine would execute it from uncached SDRAM, with additional instruction
fetch stalls. Its vblank deadline must be measured before engine bring-up;
if it exceeds the window, a shadow palette or explicit blanked palette
transition is required. Current code waits for the window but does not
provide a hardware-atomic palette commit. This is an additional unverified
DOOM integration constraint, not a limitation hidden by the video tests.
