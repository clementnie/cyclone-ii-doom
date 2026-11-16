# Development loader protocol

No extra pin/cable is required: use the configuration USB-Blaster with
Quartus 13 In-System Sources and Probes (ISSP). The source/probe instance is
logically DOOM6, serialized by Quartus 13 as OOM6, source width 480,
probe width 96. The index is discovered (currently 0). Quartus Tcl API syntax was
checked against the installed Quartus 13 help in `reports/jtag-api.txt`.
The software tests model its stable source/probe behavior, not USB/JTAG
transactions or driver behavior. Physical read-only discovery now passes;
source/probe writes and upload await authorization. See `ISSP_HOTFIX.md`.

UART/RS-232 has no implemented RTL, selected pins or confirmed host cable.
SRAM has no implemented controller and only 512 KiB; it cannot store the
engine and this IWAD. Flash has 4 MiB (4,194,304 bytes), which is 1,716 bytes
smaller than this 4,196,020-byte IWAD even before executable storage; no
Flash controller is implemented and no Flash write is authorized. JTAG was
selected because it needs no external hardware assumptions. It is a
development transport, not a permanent autonomous boot system.

## Registers and framing

The host updates one atomic 480-bit source value, then holds it until ACK.
The 15 little-endian words are `{command,address,data[13]}`. Command high
byte is opcode, low 24 bits are a nonrepeating transaction sequence. The
host checks every ACK before proceeding. No sequence wraps within an upload.
The source command crosses two synchronizer flops and two further settling
stages; the payload is then latched and remains unchanged through ACK.
Multi-bit data is a stable bundled-data crossing, not independently sampled
asynchronous bus bits. Reset flushes state; the host reconciles a stale
source with an invalid zero command, then sends a new RESET session.

CPU MMIO base is 10007000. Word offsets:

| Offset | Direction | Meaning |
|---|---|---|
| 00 | read | latched command |
| 04 | read | address |
| 08..38 | read | 13 data words |
| 40 | read/write | readback CRC result |
| 44 | read/write | command ACK |
| 48 | read/write | status |

Naturally aligned full-word data accesses only. Fetches, partial writes,
source writes and undefined offsets fault. Held requests complete once.
The probe words low to high are `{ack,result,status}`. CPU publishes result
and status before ACK; the host only trusts them when ACK matches.

| Opcode | Action |
|---|---|
| 1 RESET | data[0] = number of expected ELF segments, 1..7 |
| 2 BEGIN | address, data[0] = byte length |
| 3 DATA | next up to 52 bytes; last packet uses BEGIN's remaining count |
| 4 END | data[0] = IEEE CRC32; CPU rereads actual SDRAM and compares |
| 5 EXEC | address = aligned verified program entry |

BEGIN only accepts 20020000..20380000 program ranges, or an IWAD starting
exactly at 20380000 and ending no later than 207f0000. All verified intervals
must be disjoint; active transfers cannot nest. Firmware blocks framebuffer,
stack, on-chip RAM, MMIO, Flash and wrapping address writes. Host additionally
validates ELF executable entry/segment sizes and the entire IWAD directory.
END records a region only after readback CRC succeeds. EXEC requires exactly
the declared number of program regions plus the verified WAD. Engine startup
is responsible for its own data/BSS initialization as well as SP setup.

Any command error invalidates the session and WAD descriptor. Inactivity of
250,000,000 system clocks (5 s) invalidates an incomplete session; it also
makes the idle loader show timeout while waiting for a host. Start a fresh
RESET upload to recover. Readback CRC calculation is synchronous and can
take substantially longer than 5 s: the inactivity timer is reset after the
command finishes. Host per-command timeout is 180 s. An interrupted upload
never automatically executes. KEY0 resets the CPU to ROM without Flash.

Status D6000001 is ready/reset; D6000002/3/4 are begin/data/end; D6000005
is entry handoff. E6000000|code errors: 1 invalid manifest count, 2 illegal
BEGIN state/alignment, 3 range, 4 overlap, 5 DATA state, 6 incomplete END,
7 CRC mismatch, 8 inactivity timeout, 9 incomplete EXEC, 10 invalid entry,
11 returned program, 12 unknown opcode. The same status is written to the
existing diagnostic VGA R field (system RAM-result register). CPU traps
light LEDR0. Engine exit uses the existing diagnostic error E5000000|status.

The payload is about 4.82 MB because it includes ELF memsz zero-fill plus
IWAD. 92,693 packets acknowledge one at a time. USB-Blaster/Tcl overhead
will determine actual upload duration; no unmeasured physical throughput
claim is made. CRC32 detects transfer corruption; this is a trusted-host
development loader, not a cryptographic secure-boot mechanism.
