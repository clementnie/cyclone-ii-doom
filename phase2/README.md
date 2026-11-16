# RV32I SoC and Cyclone II diagnostic dashboard

Implemented a blocking RV32I processor, 8 KiB boot ROM, 8 KiB RAM, MMIO, a 40×30 RGB332 tile display, and a board top-level. The existing PS/2 RTL is instantiated without modification. The compiled firmware controls actual VGA output in simulation. The Starter Board EP2C20 project now defaults to diagnostic build **D1060001**; see [dashboard behavior, MMIO and images](DIAGNOSTICS.md) and [current measured results](quartus_ep2c20/RESULTS.md). The original DE2 wrapper remains available.

## Reproduce

From the repository root:

```sh
make -C phase2 firmware
make -C phase2 test
```

Required tools: Clang with RISC-V backend, LLD, llvm-objcopy, Python 3, GNU Make and Icarus Verilog. This session used Clang/LLVM 23.1.4 and the already-existing Icarus 13.0 executable in `/tmp/de2-iverilog`; the Makefile uses that location only when Icarus is absent from PATH. Override `IVERILOG`, `VVP`, `IVL_FLAGS`, `CLANG` or `OBJCOPY` for another installation. Nothing is downloaded or installed by these targets. Build products and compiler temporary files go under `phase2/build/`; the generated ROM initialization is `phase2/firmware/boot.hex`.

`boot.hex` is supplied as the ROM initialization image. The Makefile regenerates it from firmware when build intermediates are missing or sources change, so the documented full test command requires the compiler even on a fresh checkout. It contains exactly 2048 little-endian 32-bit words, zero padded to the ROM capacity. The linker rejects ROM overflow and reserves at least 1 KiB of RAM for stack. `firmware/start.S` initializes SP, copies initialized data from ROM to RAM, clears BSS and calls the C entry point. No hosted library or unsupported ISA extension is linked.

Individual targets: `compile`, `cpu-test`, `memory-test`, `vga-test`, `soc-test`, `ps2-test`, `top-test`, `pins`, `dashboard-test`, `ram-diagnostic-test`, `starter-test`. `test` runs all of them. The SoC test simulates approximately 50.4 ms and may take several minutes with Icarus. A failed assertion terminates the simulator with nonzero exit status; testbench timeouts prevent indefinite simulated execution.

## CPU contract

`rtl/rv32i_cpu.v` implements RV32I integer ALU/immediates, LUI/AUIPC, JAL/JALR, all six branches, LB/LH/LW/LBU/LHU, SB/SH/SW and FENCE. Registers are 32 bits; x0 reads as zero and ignores writes. Operands use the pre-instruction state, including JALR when destination equals source. Instruction addresses require four-byte alignment; JALR clears bit 0 before checking bit 1. Misaligned halfword/word accesses fault before issuing a data request. Loads to x0 still perform the memory access and can fault. RAM/MMIO are little-endian.

FENCE is an ordered no-op because there is one blocking request, no caches, no speculation and no write buffering. ECALL and EBREAK enter a persistent externally visible stop state. Unsupported instructions also stop, recording cause, faulting PC and value. This is an explicit bare-metal execution environment, not an implementation of the RISC-V privileged architecture. There are no CSRs, trap vector, MRET, interrupts, MMU, counters accessible as CSRs, Zicsr, Zifencei, atomics, compressed instructions or M extension. Reset is the only trap recovery mechanism. These restrictions follow the separation of base integer instructions and privileged execution described in the [RISC-V RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html).

| Cause | Stop condition |
| --- | --- |
| 0 | Misaligned instruction target |
| 1 | Instruction access fault |
| 2 | Illegal/unsupported instruction |
| 3 | EBREAK |
| 4 / 5 | Misaligned load / load access fault |
| 6 / 7 | Misaligned store / store access fault |
| 11 | ECALL, platform-defined fatal environment call |

The CPU alternates fetch, execute and optional data-access states. Bus requests remain stable through ready; a gap rearms peripherals after data transfers. No bus watchdog is implemented; an external future slave must eventually complete or return error. The current internal fabric always completes decoded accesses or faults. The register file is resettable flip-flops with combinational reads; it is not expected to infer M4K RAM. Large arrays use synchronous read templates without reset loops.

## Phase 2 address map

This deliberately uses a smaller implementation than the long-term DOOM plan; unimplemented external memories fault. Phase 2 VGA register meanings below supersede the earlier framebuffer proposal for this build.

| Byte address range / register | Implemented behavior |
| --- | --- |
| `0x00000000..0x00001fff` | 8 KiB initialized boot ROM, reset PC 0; writes fault |
| `0x00010000..0x00011fff` | 8 KiB on-chip RAM; byte enables; executable |
| `0x10002000..0x10002fff` | Existing PS/2 MMIO; only its defined offsets are valid |
| `0x10003000` | Read/write display mode: 0 pattern, 1 solid, 2 tiles, 3 diagnostics (reset default) |
| `0x10003004` | Read/write RGB332 solid color in bits 7:0 |
| `0x10003008` | Read-only completed-frame counter |
| `0x10004000` | Read/write diagnostic mailbox |
| `0x10004004` | Read-only 50-MHz cycle counter (wraps modulo 2^32) |
| `0x10004008..0x10004018` | New CPU RAM/key/error observations; see [full map](DIAGNOSTICS.md) |
| `0x1000401c` | Read-only build ID D1060001 |
| `0x10010000..0x100112bf` | 1200 write-only tile words, 4-byte stride; low 8 bits select RGB332 color |

All other addresses and undefined register offsets fault; there are no aliases. MMIO allows aligned 32-bit reads/writes only and rejects instruction fetches. Tile index is `row*40+column`, with rows 0–29 and columns 0–39. The physical array is 2048×8 bits for regular inference; software can address only 1200 cells. Read/write collisions on the same displayed tile are not given a guaranteed RAM value; a pixel may show the old or new cell during an update. Legacy tile software must initialize all visible cells before selecting tile mode. No initialized framebuffer, full-screen framebuffer or external RAM is assumed.

PS/2 retains its documented event IDs, press/release bit, queue and error recovery contract. The diagnostic firmware polls continuously, preserves sticky errors, and displays the last logical event and event count. [Existing keyboard interface](../docs/ps2-keyboard.md).

## VGA and clocking

Every internal register uses `CLOCK_50` (50 MHz). A toggle register drives output-only `VGA_CLK`; no logic uses that signal as a fabric clock. Counters and DAC outputs update on its falling phase using a clock enable. The DAC rising edge follows 20 ns later, with 40 ns between pixels. Tile RAM is read synchronously on the intervening system edge, allowing its result to settle before the next pixel launch.

Timing is 640/16/96/48 pixels and 480/10/2/33 lines (active/front/sync/back), 800×525 total, negative sync, active-low DAC blanking (`VGA_BLANK=1` during active video). At 25 MHz this is 31.25 kHz horizontal and 59.5238 Hz vertical. RGB is zero during blanking, expanded to all ten DAC bits. Composite sync is disabled with `VGA_SYNC=0`. Actual monitor tolerance and DAC analog pipeline effects remain board-test items. [ADV7123 datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/ADV7123.pdf).

Firmware now runs a scratch RAM test and displays diagnostics. Modes 0/1/2 remain available; mode 3 uses a synchronous character ROM. See [pixel pipeline and limitations](DIAGNOSTICS.md).

## Quartus and board bring-up

The separate [Quartus project](quartus/de2_phase2.qpf) preserves `cycloneiiDOOM/`. With Quartus II 13.0 SP1 and Cyclone II support available:

```sh
make -C phase2 quartus
```

The command runs firmware and static pin checks, then synthesis, fitting, assembly and timing through `quartus_sh --flow compile`. Project-relative ROM initialization is resolved from `phase2/quartus/`. See [pin and timing notes](quartus/README.md) before interpreting a compile result.

`KEY[0]` asynchronously asserts a two-stage reset-release chain. A power-up counter initialized through FPGA configuration holds reset for about 1.31 ms; release is synchronized to CLOCK_50. `LEDR[0]` indicates the CPU stopped on a trap. No unused board peripheral is exposed in this top-level; unused FPGA pins are requested as tri-stated inputs. Verify this policy against the actual board and external control pull-ups before programming.

Quartus parsing, mapping, pin legality, fitted resources and timing are not validated by Icarus. Hardware release requires a successful Quartus compile, all expected pin and I/O-bank reports, no unexplained unconstrained paths, setup/hold closure including the DAC clock output, followed by physical clock/video/reset/keyboard tests. No working physical board or DOOM performance is claimed.
