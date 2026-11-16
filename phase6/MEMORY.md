# Boot and runtime memory architecture

All addresses are byte addresses. Intervals below are half open.

| Interval | Bytes | Owner |
|---|---:|---|
| 00000000..00002000 | 8,192 | ROM loader, CPU reset PC=0 |
| 00010000..00010200 | 512 | reserved descriptor/scratch, descriptor at 10100 |
| 00010200..00012000 | 7,680 | loader BSS and stack; stack top 12000 |
| 10002000..10003000 | MMIO | existing PS/2 FIFO/status |
| 10003000..10004000 | MMIO | original diagnostic VGA |
| 10004000..10005000 | MMIO | mailbox/cycle/diagnostic registers |
| 10006000..10007000 | MMIO | framebuffer/palette |
| 10007000..10008000 | MMIO | new JTAG loader mailbox |
| 10010000..100112c0 | MMIO | diagnostic text cells |
| 20000000..20010000 | 65,536 | framebuffer A, 64,000 live bytes |
| 20010000..20020000 | 65,536 | framebuffer B, 64,000 live bytes |
| 20020000..2006e0eb | 319,723 | ELF text/rodata |
| 2006e0ec..2007ca44 | 59,736 | initialized data |
| 2007ca44..200b83a8 | 244,068 | BSS |
| 200b83a8..200b83b0 | 8 | alignment |
| 200b83b0..20380000 | 2,915,408 | bounded runtime heap, includes 2 MiB zone |
| 20380000..207806b4 | 4,196,020 | complete shareware IWAD, read only in engine |
| 207806b4..207f0000 | 457,036 | unused WAD-slot headroom, not allocated |
| 207f0000..20800000 | 65,536 | engine stack; SP initially 20800000 |

The one-byte gap before data is linker alignment. ELF file size is not the
runtime footprint. See the linked map/program headers and upload manifest.
Heap, WAD slot, stack and both frame slots reserve exactly 8 MiB together
with program/static storage and alignment; no guard is silently borrowed.
The measured malloc span is 2,388,928 bytes, leaving 526,480 bytes of heap
arena beyond its highest block. The measured stack depth is 1,568 bytes.
These measurements cover E1M1 bring-up and do not establish all-level limits.

CPU reset enters ROM at zero. Verified PT_LOAD ranges are uploaded at their
ELF physical/virtual addresses; the host rejects address disagreement,
overlap, out-of-bounds segments, and a non-executable entry. The host includes
zero bytes through each PT_LOAD memsz, and the loader CRC verifies those
bytes in SDRAM. Engine startup still initializes data/BSS itself, switches
to its reserved SDRAM stack, then calls main. CPU instruction/data requests
use the same existing SDRAM route and arbitration. There is no cache or
Harvard-only instruction restriction and no interrupt-based trap handler;
a CPU fault latches cause, fault PC and value and stops until reset.

The loader leaves `{0x57414435, 0x20380000, length, CRC32}` at 10100 after
successful WAD verification. Main checks bounds/CRC and every lump before
mounting. The libc FILE layer seeks directly into this single WAD copy;
fread copies only requested ranges, and DOOM's zone caches selected lumps.
It never mallocs a second entire WAD. Streaming and Flash are unnecessary
for this legal shareware IWAD. Oversize data is rejected with exact shortfall;
Freedoom/commercial-size IWADs are not assumed to fit.
