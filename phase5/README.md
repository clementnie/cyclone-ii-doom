# Phase 5 — first linked RV32I DOOM executable

**Built successfully; not booted.** Existing FPGA releases, RTL, pins and
timing constraints are unchanged from checkpoint d3f9b6f. The user confirmed
physical framebuffer operation before this phase. No new SOF or Quartus run
was needed, and no FPGA programming occurred.

```sh
make -C phase5          # rebuild complete engine, runtime and ELF; audit ISA
make -C phase5 test     # native ASan/UBSan runtime tests
make -C phase5 pack     # produce segments/CRC manifest; does not upload
```

Uses the existing Clang/lld/LLVM tools. Engine source and GPL notices are
reused from `../phase4b/doom/upstream/`; no engine download was needed.
`vendor/compiler-rt/` supplies the selected portable arithmetic helpers,
with Apache-2.0/LLVM-exception notices and source hashes retained. No package
was installed. Build source is fully local after this checkpoint.

## Executable and memory

Artifact: `artifacts/doom-rv32i.elf`, **473,768 file bytes**, entry 20020000.
ELF32 EXEC, little endian, RV32I/ILP32 soft float, no dynamic linker.

| Region/requirement | Bytes |
| --- | ---: |
| Text/rodata | 319,615 |
| Initialized data | 59,716 |
| BSS | 244,064 |
| Static footprint including alignment | 623,408 |
| Bounded heap arena | 2,915,536 |
| Requested DOOM zone, inside heap | 2,097,152 |
| Reserved SDRAM stack | 65,536 |
| Two reserved framebuffer slots | 131,072 |
| Reserved WAD slot, maximum | 4,653,056 |

`link.ld`: engine 20020000..200B832F; heap 200B8330..2037FFFF;
WAD 20380000..207EFFFF; stack 207F0000..207FFFFF. Frame slots remain at
20000000/20010000. Heap also contains the presentation buffer, engine video
buffer and miscellaneous allocations: zone size is not the entire heap.
Heap/stack peaks and whether real levels fit a 2 MiB zone remain unmeasured.
The upstream indexed presentation allocation still reserves four bytes per
pixel; it is not silently assumed to consume only 64,000 bytes.

`reports/unresolved.txt` is empty. `reports/doom.map`, `size.txt`,
`attributes.txt` and `status.json` preserve the link and memory evidence.
`verify_elf.py` checks 55,260 actual instruction words from function ranges
and startup (excluding merged constant data): all match the existing CPU's
RV32I encodings; no M/C/F/D/CSR instructions. Compiler attributes report
rv32i2p1. This is static compatibility verification, not execution evidence.

## Runtime and platform

All required DG functions are in `platform.c`, reusing Phase 4B INDEX8,
RGB444 palette, vblank swap, tick and seven-key PS/2 interfaces. Runtime
provides real bounded split/coalescing allocation, strings, integer parsing,
bounded formatting, a 4096-byte diagnostic log ring and read-only WAD I/O.
Console messages are retained in `phase5_log`; individual formatted console
messages are capped at 511 bytes. This is an engine-focused runtime, not a
complete POSIX libc. Config/save writes, directories and subprocesses return
explicit unsupported/read-only errors. `exit` records E5000000|status at
diagnostic MMIO 10004018 and stops. Native sanitizer tests cover allocation,
coalescing, overflow, formatting/parsing and synthetic WAD seek/read/refusal.
They do not execute the engine or compiler helpers on the FPGA.

## Boot feasibility and remaining gate

The existing CPU **supports SDRAM instruction fetch**. Phase 4 RTL explicitly
routes fetches to SDRAM; its committed simulation executes a function from
SDRAM. Phase 4B's user-confirmed hardware result establishes the framebuffer,
not that this ELF has executed. No RTL change is necessary for fetch support.

**There is no working ELF uploader/ROM loader.** The existing SOF still boots
its diagnostic ROM. `pack` successfully prepares this actual ELF's loadable
segments using the existing bounded packer. It cannot transport them to the
FPGA or transfer control. The concrete host-JTAG mailbox/handshake design is
in `../phase4b/doom/LOADING.md`; implementing its FPGA/ROM/host components is
substantial new work and is the next hardware-development boundary.

Once such a loader exists, it must load the ELF PT_LOAD bytes at their
linked addresses and place an authorized IWAD at 20380000 (within its slot).
Set four little-endian words at on-chip 10100:
`{0x57414435, 0x20380000, WAD_length, IEEE_CRC32}`. `main.c` validates bounds,
CRC and the WAD directory before mounting it, then starts doomgeneric with
`-iwad doom1.wad -mb 2 -nosound -nomusic`. Invalid/missing descriptors stop
with exit status 1. The descriptor is an implemented consumer contract,
not evidence that a loader exists. No real WAD is present or downloaded;
only a synthetic 32-byte file fixture is used in tests.

After loading works: simulate startup/heap/file access with authorized data,
measure zone/stack peaks, add Enter decoding for DOOM menus, and measure the
palette update deadline with code executing from uncached SDRAM. The reused
DG palette loop was previously tested from ROM; a shadow palette or blanked
transition may be necessary for the slower SDRAM execution path. No engine
launch, FPS or playable-hardware claim is made by this build.
