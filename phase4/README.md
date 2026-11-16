# Project DOOM Phase 4 — SDRAM bring-up

Separate Quartus project: `quartus/phase4.qpf`, EP2C20F484C7,
32-bit Quartus II 13.0 SP1. No FPGA programming is automated.
Baseline Git checkpoint: `1347b03`. Phase 2 RTL, four-byte-array RAM,
pin assignments, constraints and D1060001 release are unchanged.

## Current deliverable

CPU-accessible SDRAM candidate, full-range hardware diagnostic, independent
behavioral model and randomized/CPU-level simulations. **Not physically
validated.** PSC -G7 timing has been reconciled with the supplied marking; the
physical marking transcription and PCB should be checked against the reference. See `reference/README.md`.

```sh
make -C phase4 firmware test
make -C phase4 regression
python3 phase4/tools/audit.py
sh phase4/quartus/review.sh
python3 phase4/tools/check_timing.py
```

The Makefile defaults to the existing Icarus installation under
`/tmp/de2-iverilog`; override IVERILOG, VVP and IVL_FLAGS for system tools.
Clang/lld and llvm-objcopy build RV32I/ILP32 with no compressed, multiply,
divide, floating point, CSR or privileged instructions. Hardware traps halt;
there is no interrupt service or operating system. Loads/stores have natural
alignment checks in the CPU; the controller independently checks bounds,
size, strobes and illegal fetch/write combinations.

## Memory and reset

ROM 0x00000000–0x00001fff (8 KiB); on-chip RAM
0x00010000–0x00011fff (8 KiB), unchanged. PS/2 at 0x10002000,
VGA at 0x10003000, diagnostics/cycle counter at 0x10004000, tile RAM
at 0x10010000. External RAM **0x20000000–0x207fffff**, executable,
little endian. SDRAM address bits: bank [22:21], row [20:9],
column [8:1]; two x16 BL1 commands per word. Byte enables use DQM.
Reads return an aligned word; CPU extracts/sign extends subwords.
Out-of-range accesses go to the existing bus fault path.

The CPU holds valid/address/data until ready, then drops valid to rearm.
One deterministic client owns SDRAM in this increment; refresh wins before
accepting a pending CPU transaction. Requests in flight complete before
refresh. There is no display client yet. All logic uses PLL c0 and clock
enables; only the phase-related SDRAM clock leaves the FPGA.
KEY0 resets CPU/peripherals, while memory continues completing transactions
and refreshing. Power-on/PLL relock initializes memory and invalidates its
contents. Tests of controller rst represent cold reinitialization, not
retention across PLL loss. Existing VGA remains 25 MHz (50 MHz enable/2),
640x480, approximately 59.52 Hz.

## Diagnostic display and physical test

Build D4000001. CPU heartbeat and VGA frame count advance independently.
TEST ADDRESS shows progress; ERROR COUNT starts at zero. SDRAM shows
TEST RUNNING, then PASS - FULL 8 MIB, or FAIL with error code E400.
After completion address is 207FFFFC. KEY0 reruns the test. PS/2 FIFO is
present but this memory diagnostic does not consume keyboard events.

Firmware uses ROM and on-chip stack, so it can test all 8 MiB destructively.
It performs walking ones/zeros per bank, all address-bit probes, separate
full-memory zero/one/address/inverse sweeps and byte/halfword end-point
tests. Error count saturates; heartbeat updates throughout. Full sweeps
may take minutes on this uncached multicycle CPU; no frame-rate claim.
The simulation uses only 32 words per sweep, retaining all walking/alias
and bank-boundary probes. It is **not a full 8 MiB simulated CPU sweep**.
The independent command model exercises the full address width but is not
a vendor electrical or retention model.

Before any physical test: reconcile U6 marking and PCB with reference,
pass pin audit and both-corner timing, then assemble the reviewed design.
No SOF is approved for physical use merely by passing these simulations.
Record displayed address/count, time to PASS, reset behavior, cold power
cycles and sustained-repeat results before advancing the hardware milestone.
Recovery image: `../phase2/releases/cyclone_ii_diagnostics_D1060001.sof`.

## Following milestones

Framebuffer and DOOM are pending the first SDRAM hardware gate. Planned
160x120 indexed buffers need 19,200 bytes each; 320x200 needs 64,000.
A 160-byte double line buffer can fit in one M4K; deterministic prefetch
and vertical-blank buffer swap need independent contention/underflow tests.
Palette converts to the board's RGB444 outputs. No framebuffer is claimed.

The board reference also has 512 KiB asynchronous SRAM, 4 MiB x8 Flash
(some board variants have 1 MiB) and SD socket. None currently has a working
loader in this SoC. A ROM SD-SPI loader into SDRAM is a candidate, subject
to verified pins, card initialization and integrity checks. Boot ROM cannot
hold a DOOM executable/WAD. Actual doomgeneric code/data/heap/stack sizes
remain unmeasured; no fit or playable claim is made. Runtime must supply
soft multiply/divide, libc/file operations, allocation, tick polling and
PS/2 platform mapping. Engine source/license review and authorized WAD
selection remain pending; no WAD or engine source has been imported.

Timing reports list DRAM_CLK as an unconstrained *output data* endpoint:
it is the forwarded clock and has a generated-clock assignment. Its phase
and insertion delay are used by all SDRAM input/output checks; it is not
false-pathed. The timing checker permits only that clock endpoint, rejects
unconstrained SDRAM data/control, and rejects ignored constraints. Ordinary
asynchronous KEY/PS2 inputs retain synchronizer endpoint exceptions.

Earlier `docs/soc-architecture.md` describes an unimplemented RV32IM plan
with SRAM at 0x20000000 and SDRAM at 0x80000000. The actual Phase 2 core is
RV32I and has neither external region. This Phase 4 map supersedes that
proposal: SDRAM is at 0x20000000, and external SRAM has no mapped interface.
Future SRAM mapping must choose a disjoint region (for example 0x30000000).

`make -C phase4 candidate` runs review, then the normal full compile
(including the unchanged warning-only hardware hook), rechecks final timing,
and archives `candidates/reference_sdram_D4000001.sof`. It is a **reference
board candidate**, conditional on U6 identification and PCB timing budgets,
not a physically validated release. The script never invokes a programmer.


The Phase 4 CPU copy adds a DECODE cycle to register source operands,
fixing the measured register-file/ALU setup path without changing the ISA.
The original Phase 2 CPU is preserved. The same 507 instruction retirement
checks and 16 trap cases pass, as does the SDRAM diagnostic with actual
instruction fetch/return from SDRAM (simulation-only execution probe).
`reports/phase2-with-phase4-cpu-regression.log` records the existing SoC
regression rebuilt with this CPU variant. This change trades one cycle per
instruction for timing closure and also reduces fitted logic use.

Exact physical test steps and expected display/reset behavior:
[HARDWARE_TEST.md](HARDWARE_TEST.md). Hardware evidence is required before
marking SDRAM complete or proceeding to the framebuffer milestone.
