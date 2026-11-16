# Hardware

Target: Cyclone II Starter Board / DE1, FPGA EP2C20F484C7 (ordering suffix N
may appear on the device). This is not the larger EP2C35 DE2 used in early
planning notes. The fitted Phase 9 source of truth is `phase9/quartus/phase9.qsf`.
It uses 3.3-V LVTTL, a 50 MHz oscillator, KEY0 reset, LEDR0 status, PS/2,
a four-bit-per-channel VGA DAC and 8 MiB x16 SDRAM.

The memory timing was developed for the supplied PSC -G7 device marking.
Verify chip marking, board revision and electrical pinout against your own board
before programming. Archived vendor PDFs and schematics are excluded from this
repository; obtain the appropriate manual from the board manufacturer.

| Signal | FPGA pin / definition |
| --- | --- |
| CLOCK_50 | L1 |
| KEY[0] | R22 |
| PS2_CLK / PS2_DAT | H15 / J14 |
| VGA_HS / VGA_VS | A11 / B11 |
| SDRAM address/data/control, RGB | Full assignments in Phase 9 QSF |

Connect a PS/2-capable keyboard, VGA monitor and USB-Blaster. A USB-only keyboard
with a passive adapter is insufficient. PS/2 lines are inputs with synchronization
and filtering; the core does not drive host commands. No audio output is implemented.

PLL c0 clocks system logic at 50 MHz; c1 drives SDRAM at 50 MHz with an 8 ns
phase shift. Pixel timing uses a divide-by-two enable. Cold start/PLL relock
initializes memory; KEY0 resets CPU/peripherals while memory refresh continues.
A SOF programs volatile configuration SRAM. No Flash programming is required.

The recorded Phase 9 fit occupies 14,732/18,752 LEs, 52/52 M4Ks, eight 9-bit
multiplier elements and one PLL. Worst recorded setup/hold slack is +2.069/+0.215 ns.
These are preserved reports from Quartus II 13.0 SP1, not a rebuild during publication.
