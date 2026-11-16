# Phase 4 checkpoint: awaiting physical SDRAM test

D4000001 candidate: `candidates/reference_sdram_D4000001.sof`.
See `HARDWARE_TEST.md` before manual programming. No programmer was run.
Baseline checkpoint `1347b03`; the D1060001 release and Phase 2 are unchanged.

| Item | Evidence / status |
| --- | --- |
| SDRAM controller + CPU region | Simulation passes, 8 MiB at 20000000–207FFFFF |
| Actual SDRAM reference | PSC A2V64S40CTP-G7, manufacturer spec retained; reconcile abbreviated marking |
| Initialization / refresh | 200 us wait, PRE, 8 REF, MRS; refresh under load and idle tested |
| Memory semantics | Random/sequential word, byte/halfword masks, banks/rows, boundary faults, read-after-write |
| CPU access | Diagnostic sweeps shortened to 32 words in simulation, all bank/address-bit probes retained |
| CPU execution | Fetch/return from SDRAM passes; full instruction trace 507 states, 16 trap cases |
| Reset | Warm CPU reset while memory busy; refresh continues; diagnostic restarts and passes |
| Regressions | Original suite and original SoC rebuilt with Phase 4 CPU pass; PS/2 640 checks each at 25/50 MHz |
| Full Quartus flow | 32-bit 13.0 SP1 synthesis, fit, assembly, both-corner timing pass; original hook runs |
| Resources | 5,757 LEs, 38/52 M4Ks, 1 PLL, no multipliers |
| Worst setup / hold | +2.069 ns / +0.215 ns, all data/control paths constrained |
| SDRAM in/out setup | Slow: +2.069/+3.257 ns; fast: +3.559/+3.721 ns |
| Observed request latency | 27 cycles maximum after init, including a refresh-deadline request |
| Hardware SDRAM evidence | **Not yet available. Full 8 MiB test not yet run physically.** |
| Framebuffer | Pending SDRAM hardware gate |
| DOOM/runtime/loader/WAD | Pending; no executable memory-size, FPS or playable claim |

Timing closure required an operand register stage in the Phase 4 CPU copy.
It retains the ISA, adds one cycle per instruction and lowers logic use.
A PLL phase adjustment to 8 ns balances SDRAM read/command margins.
Neither changes the preserved baseline. No timing check was relaxed.
The old failed fits are retained under reports/ for transparency; final
measurements are in `reports/timing-summary.json` and `resource-summary.txt`.
Build-input hashes prevent stale timing reports from being accepted.

The behavioral SDRAM model is independent of the controller but is not a
vendor electrical/retention model. Interface budgets include provisional
1 ns PCB allowance and 7 pF load; they still need physical confirmation.
The clock pin itself appears as an unconstrained data-output endpoint;
it is the generated timing reference and is not false-pathed. There are no
unconstrained SDRAM data/control paths. Asynchronous inputs and VGA retain
the documented baseline exceptions and routing budgets.
