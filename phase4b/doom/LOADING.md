# Loader and asset design — not yet implemented in hardware

The frame diagnostic boots directly from the existing 8 KiB ROM. The minimal
DG platform test also fits ROM (1,583 text bytes); its 65,040 B BSS is in
SDRAM and is initialized by the RV32I startup path. Its full CPU/SDRAM/VGA
simulation uses no loader and does not prove a large executable can boot.

The engine object currently needs about 629 KiB text/data/BSS before zone,
allocator metadata, presentation allocations and assets. It cannot fit ROM.
`engine.ld` places a loaded executable at 20020000, after both frame slots,
with a 64 KiB reserved SDRAM stack and the remaining heap bounded by linker
symbols. Startup copies initialized data and clears BSS after loader checks.

Practical host-assisted first loader design: use the board's existing
USB-Blaster JTAG connection, which already configures the FPGA. Add a small
Altera in-system source/probe mailbox behind the CPU bus in a **future
loader revision**, with no additional FPGA pins. Quartus 13 SignalTap/JTAG
source/probe support is the intended host transport. Neither that mailbox
nor its hardware/host handshake is present in this framebuffer candidate.
Do not try to send payloads to the current diagnostic image.

Proposed mailbox: 32-bit DATA and COMMAND sources; STATUS and CRC probes.
Every command carries a sequence number; CPU acknowledges exactly that
number before host advances. CPU loader, resident in ROM, accepts SET_ADDR,
SET_LENGTH, DATA_WORD, END_CRC32 and EXEC commands. Reject unaligned addresses,
SDRAM overflow, overlap with framebuffer slots, truncated payloads and CRC
mismatch. Endianness is little endian; partial final word has an explicit
byte count. EXEC is allowed only after the whole executable is validated.
Loader keeps heartbeat/VGA alive and never executes an unverified partial
image. Host sends ELF loadable segments, then a descriptor for authorized
WAD bytes, then starts the linked entry address. Reset must return to ROM.

A whole memory-backed WAD is simplest for initial bring-up. Engine default
zone is 6 MiB and cannot coexist with a several-megabyte WAD in 8 MiB.
`engine_main.c` explicitly requests `-mb 2` (upstream supports it without a
source patch). Its actual level compatibility and allocation peaks are
**unverified**. Host packer must enforce total segment + BSS + heap/zone +
WAD + stack + framebuffer limits and record payload sizes/CRC. No WAD has
been imported. If 2 MiB zone is insufficient, use streamed files from SD or
board Flash after those interfaces are implemented and verified; none is
currently available to this SoC. SRAM is 512 KiB and is not a substitute for
an executable/WAD store. Flash capacity varies by board and is not assumed.

This is a documented host-assisted loading design, not a working loader.
The missing JTAG mailbox/host uploader, libc/file layer, compiler soft-float
helpers and authorized WAD remain explicit DOOM execution blockers.


Proposed resident-WAD partition (enforced by `engine.ld` heap bound):
engine text/data/BSS start20020000; heap ends20380000; WAD occupies
20380000..207EFFFF (maximum4,653,056 bytes); stack207F0000..207FFFFF.
With the current object footprint, roughly2.78 MiB remains between engine
BSS and WAD base, including the2 MiB zone and all other malloc allocations.
Actual final-link alignment/runtime overhead and allocation peaks still need
measurement. Host must reject any WAD exceeding the slot. The ROM loader
would leave a descriptor {magic,base,length,CRC32} at on-chip10100 for a
read-only memory-backed WAD file layer. No such file layer is implemented.

The proposed JTAG mailbox is a clock-domain crossing: synchronize request
and acknowledge toggles through two flops, hold DATA/COMMAND stable until
acknowledged, and capture the payload only after the synchronized request.
Reset must reconcile sequence/toggle state on both sides. Directly wiring
asynchronous JTAG source bits into the CPU bus is not an acceptable loader.
