# DE2 Phase 2 project inputs

Target is `EP2C35F672C6`, original Terasic DE2. The QSF includes only the Phase 2 RTL and the three preserved PS/2 files. It has explicit location and 3.3-V LVTTL assignments for all 40 exposed port bits. `pins.csv` records the intended mapping; `make -C phase2 pins` checks QSF/CSV/top-level agreement, duplicate balls, source paths and ROM image length. This is a static consistency test, not a fitter legality check.

All 40 pin values were verified directly against Terasic's official [original DE2 pin table](http://www.terasic.com.tw/attachment/archive/30/DE2_Pin_Table.pdf). The downloaded PDF and extracted table are retained in `reference/`. The static checker compares against both that official table and `pins.csv`. Quartus 13 QSF targets must use double quotes: the previous brace-delimited targets were stored with literal braces, causing all locations and I/O standards to be ignored. Do not use DE2-70 or DE2-115 constraints. Physical board revision, FPGA marking and electrical compatibility still require inspection.

The SDC constrains the 50-MHz system clock, the divide-by-two toggle register, and the forwarded DAC clock at VGA_CLK. Quartus merges `video|phase` into the identical `cycles[0]` toggle (see the map report's Removed Registers table). This is register merging, not a source-level counter-clocked process. Declaring the divider before the forwarded clock removes the unassociated-clock and missing-source-path warnings. The SDC requires exactly one matching divider register and stops on a missing or ambiguous match. The uncertainty command uses the Quartus 13 `-from` / `-to` syntax. The reset exception uses top-level `reset_pipe[*]`, without an incorrect required hierarchy prefix. DAC/control output budgets are 5 ns setup and 2 ns hold, including provisional board skew; the ADV7123 Rev. D timing tables specify at most 0.5 ns minimum setup and 1.5 ns minimum hold across the cited supply tables. [Analog Devices datasheet, Tables 5–6](https://www.analog.com/media/en/technical-documentation/data-sheets/ADV7123.pdf). These deliberately conservative budgets must be reconciled with actual PCB skew and the fitted DAC variant before hardware release.

The clock-enable protocol launches RGB/blank/sync on DAC falling phases, verified digitally. TimeQuest may conservatively analyze additional 50-MHz launch edges because the register clock is faster than its enable. No multicycle exceptions were added to suppress such paths. Inspect clock propagation to VGA_CLK and both setup/hold reports; if pessimistic paths fail, prove the enable relationship before changing constraints or rework the output clock architecture. RTL simulation is not timing closure.

Only PS/2 inputs to their first synchronizer stages, button input to the reset-release chain, and the asynchronous LED output are false-pathed. Confirm that every collection in the SDC resolves after elaboration, that the second synchronizer stages are timed, and that reset recovery/removal is handled appropriately. Do not ignore missing-collection or unconstrained-path warnings. No SDRAM, SRAM or PLL clocks are declared because those interfaces are absent from this phase.

Quartus II 13.0 SP1 is installed at `<quartus-bin>` but is absent from PATH. Compilation was run using an explicitly approved sandbox exception because the legacy executable hit a blocked system call inside the sandbox. No tools were installed. Use the **32-bit default executables** for this project on this machine: two 64-bit fitter attempts consumed CPU without advancing past placement preparation, whereas the identical 32-bit diagnostic completed all stages in 58 seconds. This observation does not establish the internal cause of the 64-bit stall. Original failed reports and edited-file backups are in `backups/pre-fit-fix/`; existing databases were retained. The optimized byte-lane RAM RTL was not changed.

See `COMPILATION.md` for the final stage results, measured resources, slack, remaining warnings, and programming-file status. Logs and repeatable timing/pin audits are in `verification/`. Physical board revision, DAC/PCB timing budgets, and hardware behavior still require review; successful compilation alone is not programming clearance.

Reproduce from this directory with an approved Quartus execution environment:

```sh
<quartus-bin>/quartus_sh --flow compile de2_phase2
<quartus-bin>/quartus_sta -t verification/audit_timing.tcl
python3 verification/check_fitted_pins.py
```

Run `make -C phase2 test` from the repository root for the complete RTL regression. The independent `report_ucp` audit lists intentional asynchronous exceptions separately from a forwarded clock output that has no data output-delay requirement. No exceptions were added simply to remove report entries.
