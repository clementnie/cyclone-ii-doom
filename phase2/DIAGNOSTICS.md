# Cyclone II diagnostic dashboard — D1060001

Target: Cyclone II Starter Board EP2C20F484C7N (Quartus EP2C20F484C7).
The default screen is a black 640×480 display with doubled 5×7 white glyphs,
hexadecimal counters, three 176×64 full-intensity RGB rectangles and a white
moving refresh marker. [Simulation capture](dashboard.png) uses testbench
values; it is not a photograph or proof of a hardware test.

The RV32I CPU, synchronous 8 KiB boot ROM / 8 KiB byte-lane RAM, PS/2
receiver/decoder/FIFO, reset circuitry, 50 MHz clock, 800×525 / 25 MHz VGA
raster and physical four-bit RGB mapping are retained. The dashboard adds
one 512×8 character ROM, fixed text selection, five firmware-owned MMIO
registers and frame snapshots. There is no framebuffer or text RAM.
Existing pattern/solid/tile modes 0/1/2 and the tile RAM aperture still work;
mode 3 selects diagnostics and is now the reset default.

## Reading the screen

- **CPU HEARTBEAT / CPU:** the original mailbox register, incremented only by
  RV32I instructions, approximately every 10 ms after the startup RAM test.
  Firmware polls the hardware cycle count; it does not depend on VGA frames.
- **VGA FRAMES / HW:** controller frame counter, incremented at raster wrap.
  It and the moving marker continue if the CPU stalls. The displayed count
  is latched at the start of vertical blank and is therefore a completed
  snapshot, rather than the instantaneous raster count.
- **PS/2 CPU:** WAIT FOR KEY, EVENTS SEEN, FIFO OVERFLOW or RX ERROR. Status,
  last event and event count are firmware observations. There is no keyboard
  connection-detect input: silence cannot distinguish an idle, absent or
  incompatible keyboard. A CPU stall freezes these observations.
- **LAST EVENT / CPU:** existing decoded logical ID (0 up, 1 down, 2 left,
  3 right, 4 Ctrl, 5 Space, 6 Esc), plus hexadecimal 100 for key down.
  Space press is 00000105; release is 00000005. This is not a raw scan code
  or ASCII character. Other keys are intentionally ignored by the preserved
  decoder. The event counter counts accepted state changes, including release;
  repeated make codes for an already-held key do not increment it.
- **RAM CPU:** NOT TESTED until firmware completes all four write/read sweeps
  over a linker-owned 4 KiB scratch array; then PASS or FAIL. The sweeps use
  zero, all ones, address-dependent data and its complement. Volatile reads
  and writes ensure the test actually accesses RAM. Initialized-data and BSS
  startup checks run first. Failure preserves the screen and heartbeat.
- **ERROR CODE:** zero means no detected error, not that every board component
  passed. Trap and stale-heartbeat codes come from hardware. All values reset
  with KEY0; ordinary PS/2 errors remain sticky until reset in this firmware.
- **BUILD D1060001:** fixed hardware/MMIO identifier for this revision. A screen
  without this header/build is an older image. Increment both the text and
  MMIO constant for future dashboard revisions.

All fields are latched together in vertical blank to avoid split hexadecimal
values in photographs. Firmware observations may lag events by a polling
iteration. The RAM test reports only the reserved scratch area, not its live
stack, all internal RAM, external SDRAM/SRAM/flash, or the board as a whole.
External memory is not connected to the current SoC; testing it requires a
controller, pin/electrical review and additional RTL, not more display memory.
Analog VGA voltage, monitor compatibility, keyboard power and electrical
integrity cannot be established by this internal diagnostic.

## Error codes

| Hex code | Source and meaning |
| --- | --- |
| 00000000 | No error detected |
| 0000E001 | Firmware initialized-data/BSS startup mismatch; firmware then traps |
| 0000E002 | Firmware scratch RAM comparison failed |
| 0000E003 | Firmware observed PS/2 FIFO overflow |
| 0000E004 | Firmware observed PS/2 receive/sequence error |
| 0000E005 | Hardware saw no heartbeat change for approximately 61 VGA frames |
| E1000000 + cause | Hardware CPU halt/trap, low nibble is existing CPU cause |

Hardware trap takes precedence over stale heartbeat, then the firmware code.
Consequently a startup mismatch leaves E001 in MMIO but displays the ensuing
breakpoint trap E1000003. A resumed heartbeat clears E005 on the next snapshots;
a CPU trap remains until reset. Firmware RAM failure takes precedence over
PS/2 errors; RX error takes precedence over FIFO overflow.

## MMIO compatibility and additions

All MMIO accesses require aligned 32-bit loads/stores, as before. Read-only
writes, unsupported offsets, instruction fetches and partial IO writes fault.
Existing memory ranges and all keyboard/video/tile addresses are unchanged.

| Address | Access | Meaning |
| --- | --- | --- |
| 00000000–00001FFF | RO | Existing boot ROM |
| 00010000–00011FFF | RW | Existing internal RAM |
| 10002000 | RO/pop | Existing decoded keyboard event, bit 31 valid |
| 10002004 | RO | Existing FIFO status, bits 10 error / 9 overflow / 8 nonempty |
| 10002008 | WO | Existing clear/flush controls (dashboard firmware does not clear) |
| 1000200C | RO | Existing keys-down bitmap |
| 10003000 | RW | Existing mode, now 3 at reset |
| 10003004 | RW | Existing RGB332 solid color |
| 10003008 | RO | Existing live hardware frame count |
| 10004000 | RW | Existing mailbox, now CPU heartbeat |
| 10004004 | RO | Existing hardware cycle count |
| 10004008 | RW | New firmware RAM result: 0 untested, 1 pass, 2 fail |
| 1000400C | RW | New firmware keyboard status snapshot |
| 10004010 | RW | New firmware last logical key event |
| 10004014 | RW | New firmware event count |
| 10004018 | RW | New firmware error code |
| 1000401C | RO | New build ID D1060001 |
| 10010000–100112BF | WO | Existing 1,200 word-addressed RGB332 tiles |

New diagnostic registers reset to zero and have no hardware increment path.
The display accepts PASS only for RAM result exactly 1; all unrecognized
result values render NOT TESTED. The trusted firmware writes 1 only after
all comparisons succeed.

## Pixel pipeline

All logic uses the original 50 MHz clock and phase enable. Raster x/y advance
on phase=1, when RGB/HS/VS/blank launch together. On the intervening phase=0
edge the synchronous font ROM reads the character and glyph row for that
pixel. At the following phase=1 edge its registered glyph and unchanged
x[3:1] select the same doubled column. There is no extra character-address
register to introduce a cell of latency. The original synchronous tile read
is unchanged. Tests compare every pixel across character, line, active/porch
and frame boundaries, as well as preserving the original DAC phase checks.

## Reproduce and recover

From `phase2`, `make test` runs the original suites plus dashboard pixels,
firmware RAM fault injection and the Starter Board wrapper test. The legacy
pin parser now accepts both valid bare and quoted Quartus targets. It still
rejects braced names and checks all 40 exact locations and IO standards.
This fixes its prior false failure on Quartus-rewritten QSF files.

The versioned offline image is
[cyclone_ii_diagnostics_D1060001.sof](releases/cyclone_ii_diagnostics_D1060001.sof).
The old demo is [original_pre_dashboard.sof](releases/original_pre_dashboard.sof)
and remains in the checkpoint. `releases/SHA256SUMS` identifies both.

From `phase2/quartus_ep2c20`, the normal 32-bit Quartus command is:

```sh
QUARTUS_64BIT=0 <quartus-bin>/quartus_sh --flow compile ep2c20_phase2
QUARTUS_64BIT=0 <quartus-bin>/quartus_sta -t audit_timing.tcl
```

Quartus requires approved execution outside the sandbox in this environment.
The full flow executes the original pre-flow hardware hook; it was already
warning-only at task start and remains byte-identical. All constraints and
pin assignments are preserved. No programmer was invoked.

`sh run_review.sh` remains an optional map/fit/timing-only flow. After a new
full build, copy `output_files/ep2c20_phase2.sof` to the versioned release
path (bump the build ID for changed firmware/RTL), update the release
checksums and input manifest, then run `python3 audit_project.py`. The audit
checks the checkpoint, protected inputs, fitted pins, M4K/timing budget,
Assembler success/device, the new release copy and the original image. It
tolerates only Quartus's quoted-to-bare target spelling rewrite and the two
new Verilog source assignments in QSF. Retained build evidence is under
`quartus_ep2c20/reports/dashboard/`.

See [checkpoint recovery](../checkpoints/README.md) and
[measured results](quartus_ep2c20/RESULTS.md). The offline SOF is assembled for
the exact device; this does not verify physical PCB revision, electrical
loading or the attached monitor/keyboard. No physical FPGA programming was
performed.
