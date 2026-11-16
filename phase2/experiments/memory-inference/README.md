# On-chip memory inference experiment

The four-byte-array implementation is retained in `../../rtl/onchip_memory.v`
because Quartus II 13.0 SP1 experimentally infers block RAM and reduces synthesis
time and logic usage. `onchip_memory.original.v` is the exact pre-edit backup;
`onchip_memory.byte-lanes.v` is the tested candidate. `sha256.json` identifies
both sources and the captured ROM image. No CPU, VGA, PS/2, or bus RTL was edited.

## Measured comparison

Installed tool: Quartus II 32-bit 13.0.1 Build 232, SP1 SJ Web Edition.
Both fresh standalone projects use `onchip_memory` as top, EP2C35F672C6,
identical default synthesis settings and the same 2048-word boot image.
Times below are Quartus-reported elapsed times, excluding launch/approval time.
The candidate map briefly overlapped the baseline map; these are single trials,
not a controlled performance benchmark. The inference/resource difference is
decisive independently of timing noise.

| Analysis & synthesis | Original | Four byte lanes |
| --- | ---: | ---: |
| Elapsed time | 116 s | 1 s |
| Total logic elements | 117,513 | 51 |
| Dedicated logic registers | 65,572 | 4 |
| Block memory bits | 65,536 (ROM only) | 131,072 (ROM + RAM) |
| Inferred altsyncram instances | 1 ROM | 1 ROM + 4 RAM |
| Warnings / errors | 7 / 0 | 7 / 0 |

The candidate fitter completed in 4 s: 51 LEs, 32 M4Ks total (16 ROM,
four per RAM lane), with `Old data` mixed-port read-during-write for every lane.
The original map infers only the ROM; RAM becomes registers/mux logic.
Its 117,513 mapped LEs already exceed this device's 33,216 LEs. The optional
baseline fitter was stopped after approximately four minutes without a final
report; no physical baseline M4K count or completed fit comparison is claimed.
The unchanged inferred ROM alone corresponds to 16 M4Ks in the candidate fit. See the
preserved reports under `reports/` for stage details. RAM segments reported by
map are not physical M4K block counts.

Both map reports have the same warning categories: parallel compilation is
unlicensed (20028), three unused ROM write-side signals (10030), and unused
address bits 0 and 1 (21074/15610). The isolated fitter has no physical pin
assignments or SDC: its warnings about pins, timing constraints, output loads,
license, and default unused-pin configuration are expected for this diagnostic
project. Do not program its output onto a board or interpret it as timing
closure. Full-system fitting, timing, and hardware validation remain separate.

## Preserved behavior

ROM is still 2048x32 initialized by the unchanged `ROM_FILE` parameter. RAM is
four independent 2048x8 arrays with registered reads in the existing clocked
process. `ram0` maps bits 7:0 through `ram3` bits 31:24. Neither memory nor
read-data registers are reset. Nonblocking reads return pre-write data on a
write edge and continue every clock even with `valid=0` or `rst=1`.

Address decode is unchanged: ROM `[0x00000000,0x00002000)`, RAM
`[0x00010000,0x00012000)`, indexed by `addr[12:2]`. Low bits remain ignored
at this module boundary. Ready/error/select/served state, one response per
held request, write gating during reset/fetch/invalid addresses, and the
existing sticky error behavior are unchanged. Reset clears the response
state and suppresses writes without clearing stored data.

The full `make -C phase2 test` rerun passed (exit 0): compile, CPU, traps,
memory/MMIO, VGA, SoC firmware, PS/2 at 25/50 MHz, project/pin consistency, and
board-top reset/reboot. The transcript is `reports/regression.log`. The existing
SoC bench emits two array-sensitivity warnings.

The direct equivalence test compares ready, error, and all read data every
cycle using case inequality, including unknowns. It passes 24,177 cycles:
all RAM addresses initialized through the interface, all 16 masks, held-valid
writes, reset, instruction accesses, decode boundaries, and deterministic
random inputs. This is simulation evidence, not formal proof.

## Reproduce

From the repository root, with an installed Quartus supporting Cyclone II:

```sh
python3 phase2/experiments/memory-inference/compare.py \
  --quartus-bin <quartus-bin> \
  --output /tmp/memory-inference-new-run
make -C phase2 test
```

Choose a new output directory each time. The script refuses an existing one,
runs map then fit sequentially for each variant, captures logs and wall time,
and bounds each stage to 600 seconds. `--prepare-only` creates projects without
running tools. It never deletes or cleans any database. Run outside a restrictive
sandbox if the legacy tool's system calls are blocked.

To repeat direct equivalence from `phase2/` (adjust Icarus paths if installed):

```sh
sed 's/module onchip_memory #/module onchip_memory_original #/' \
  experiments/memory-inference/onchip_memory.original.v \
  > build/memory-inference/onchip_memory_original.v
/tmp/de2-iverilog/usr/bin/iverilog -B /tmp/de2-iverilog/usr/lib/ivl \
  -g2012 -s tb_equivalence -o build/memory-inference/tb_equivalence \
  experiments/memory-inference/tb_equivalence.sv \
  build/memory-inference/onchip_memory_original.v rtl/onchip_memory.v
/tmp/de2-iverilog/usr/bin/vvp build/memory-inference/tb_equivalence
```

The initial regression's static project check encountered a stale entry in
`build/preserved.json` for a vanished Quartus `.flock` file. The exact old
manifest is saved in `preserved.before.json`. Only generated `/db/` entries
were removed from this build-time manifest; all original QSF/QPF and PS/2 source
hash checks remain enabled and unchanged. No original database file was removed
or modified by this experiment. The existing checker source was not changed.
