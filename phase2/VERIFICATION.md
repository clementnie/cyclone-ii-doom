# Historical Phase 2 verification report

For current diagnostic firmware, full regression, EP2C20 resources and timing, see
[current results](quartus_ep2c20/RESULTS.md). The report below records the original
DE2 implementation before the Starter Board port and diagnostic changes.

Run date: 2026-11-13. Tools: Icarus Verilog 13.0, Clang/LLVM 23.1.4, LLD and Python 3 already available locally. No tools, CPU cores or game ports were downloaded or installed for Phase 2. No sudo or sandbox escalation was used. Existing PS/2 files and the original Quartus project were checked against content hashes and preserved.

| Check | Actual result |
| --- | --- |
| Full board top-level, Verilog-2005 compile | PASS, no RTL compile warnings |
| CPU directed + seeded random reference comparison | PASS, 507 retired states; PC and all 32 registers compared each time; randomized request stalls |
| CPU exceptions/system behavior | PASS, 16 cases: ECALL, EBREAK, unsupported opcode/M/CSR/FENCE.I, load/store/instruction alignment and access faults |
| Memory/MMIO | PASS, 37 transactions: byte/halfword lanes, boundaries, ROM protection, illegal fetch/write suppression, decode errors, held-request single completion |
| VGA | PASS, 3 complete frames, 1,260,000 pixels checked; sync/blank/RGB, pattern, solid and tiles; 40-ns pixel period and 20-ns launch-to-sampling interval |
| Firmware build | PASS, 448 bytes text + 4 bytes initialized data; 4 bytes BSS; boot image 452 bytes padded to 8192 bytes |
| CPU + firmware + VGA + PS/2 | PASS, 11 frames / 184.8 ms simulated; startup data/BSS checks; pattern, red, green, tile animation; keyboard make/break consumed through CPU MMIO |
| Original PS/2 regression | PASS, 640 checks at 25 MHz and 640 checks at 50 MHz; files unchanged |
| Board top-level simulation | PASS, configuration power-on hold, synchronized KEY0 reset/reboot, ROM path, output clock |
| Project source/pin consistency | PASS, exact device and 40/40 top-level bits with unique locations and I/O standards |
| Quartus synthesis/fitting/assembly/TimeQuest | NOT RUN: Quartus not found |
| Physical DE2 | NOT RUN: no board/programmer verification |

There are no outstanding failing RTL assertions from the completed tests. Two Icarus warnings in the integration test describe sensitivity to the entire tile array for testbench `wait` observations; these are not RTL or synthesis warnings. The reference interpreter is a project-local differential oracle, not the official RISC-V architectural certification suite. Directed tests cover all RV32I integer instruction classes, but no formal correctness or exhaustive encoding proof is claimed.

Run `make -C phase2 test` to reproduce the regression. Current run logs are in `build/integration.log`, `build/cpu-ps2.log`, `build/final-checks.log` and `build/soc-final.log` and `build/top.log`. Build logs are local generated artifacts; checked-in testbenches and generators are the reproducible evidence. Final results refer to the final memory-write fault guard; its focused regression rejects a malformed instruction-fetch write without changing RAM.

## Resources and limits

| Resource | Source-level allocation | Fitted measurement |
| --- | --- | --- |
| Boot ROM | 2048×32 bits, 8 KiB | Unknown |
| General RAM | 2048×32 bits, 8 KiB | Unknown |
| Tile RAM | 2048×8 bits, 2 KiB; 1200 visible cells | Unknown |
| CPU register file | 32×32 resettable register declaration; x0 never written | Unknown |
| PS/2 event FIFO | 32×9 bits plus control | Unknown |
| Logic elements / Fmax / slack | Not estimated as measured values | Unknown |
| PLLs / embedded multipliers requested | 0 / 0 | Unconfirmed by fitter |

The three large arrays total 18 KiB, nominally 36 M4K blocks at 512 ordinary bytes/block before mapping/optimization. This is a planning count, not a Quartus resource report. Register-file, FIFO and control mapping can consume additional LEs or RAM. No claim is made that timing closes at 50 MHz. There is no external-memory controller, RV32M support, DOOM engine or full-resolution framebuffer in this build.

Remaining blockers to a hardware-ready result are concrete: obtain access to an existing compatible Quartus installation, run the project and review inferred RAM/pin/clock/timing reports; then use the physical original DE2 to verify clock, reset, VGA DAC output, monitor lock and PS/2 behavior. The user prohibited unapproved tool installation, so no installation was attempted. Compilation and physical verification are not inferred from successful simulation.
