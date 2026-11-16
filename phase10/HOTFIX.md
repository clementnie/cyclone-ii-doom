# Physical upload CRC hotfix

The original Phase 10 SOF is faulty for physical uploads. Use the uniquely
named `block32_crcfix` candidate identified below. The corrected SOF has not
been programmed by the agent; complete physical upload validation is pending.

## Exact failure and evidence

`phase6/firmware/loader.c`, opcode 4 (`END`), computes IEEE CRC32 by reading
actual SDRAM and writes it to RESULT. Error 7 is a checksum mismatch. The
loader then invalidates its active manifest. This is successful rejection of
bad readback, not an ISSP discovery error or a packet-count limit.

For the unchanged default Phase 10 ELF and IWAD, the stream is:

| Packet | Command | Operation | Range / expected CRC |
| --- | --- | --- | --- |
| 1 | 01000001 | RESET | two ELF segments |
| 2 | 02000002 | BEGIN | first segment, 438548 bytes |
| 3–8436 | 03xxxxxx | DATA | 8434 packets; final packet has 32 meaningful bytes |
| 8437 | 040020f5 | END | `0x20020000–0x2008b113`, CRC `c5938c86` |
| 8438 | 020020f6 | BEGIN | second segment, 298068 bytes |
| 14172 | 0400375c | END | `0x2008b114–0x200d3d67`, CRC `10c448be` |
| 14173 | 0200375d | BEGIN | IWAD, 4196020 bytes |
| 94867 | 04017293 | END | `0x20380000–0x207806b3`, CRC `162b696a` |
| 94868 | 05017294 | EXEC | entry `0x20020000` |

8192 was the last periodic progress message, not the exact failing count.
The first segment spans SDRAM bank 0, rows `0x100–0x458` under the existing
mapping. No second-segment or IWAD packet had been attempted at the rejection.

The already-programmed board was accessible. A read-only probe returned
`E6000008873FB4A2040020F5`: ACK still identifies the failed END and RESULT
retains CRC `873fb4a2`; the status had subsequently become the normal loader
idle-timeout error 8. Small RESET/BEGIN/DATA/END diagnostics were then run on
that existing configuration, without EXEC, configuration, or Flash writes.
Raw results are in `reports/hotfix/hardware-diag.log` and their inputs are in
`diag-cases.json` / `gen_diag.py` beside it.

All 16 fully initialized, whole-block physical tests at four different bases
match exactly this transformation of each 32-byte block:

```
expected halfwords: h0 h1 h2 ... h14 h15
actual halfwords:   h1 h2 h3 ... h15 h15
```

The tests include the ELF base, its ending area, the IWAD base, and different
sizes. For 32/64/128/512 bytes, physical CRCs are respectively
`b46e1855`, `75b35a4d`, `1140c8ab`, `476298cd`, instead of
`13d6e8c3`, `d5cda253`, `f5eed1d4`, `b8ce8d07`.
Applying the same per-block transformation to the first ELF segment, with zero
in the two following sampled bytes, predicts **873fb4a2**, the exact retained
physical failure CRC. `tools/test_upload_hotfix.py` checks this evidence.

This identifies misaligned capture in Phase 10's new continuous block-read
pipeline: the assembled block starts one halfword late and includes a stale
last sample. CRC checking exposes the fault. Address boundaries, ACK state,
CRC algorithm, and whole-word write byte enables do not explain a transformation
that repeats at every block boundary. The fault is not stale block-buffer tags:
it occurs on fresh readback at multiple unrelated bases. The actual DQ waveform
was not captured; the electrical reason that the continuous sampling alignment
differs from the original digital model is not independently measured.

## Comparison and repair

Phase 9 uses isolated BL1 reads, a WAIT interval, and registered DQ capture.
Phase 10 introduced sixteen consecutive READs and assumed capture starting at
stream count 4. Its original simulation model agrees with that assumption but
does not reproduce the observed physical alignment. The mailbox and SDRAM
arbiter are identical to Phase 9 apart from module names. The new CPU cache
lines and four block buffers retain write-through invalidation.

The RTL fix is confined to `rtl/phase10_sdram_controller.v`: fill the existing
32-byte blocks with sixteen isolated READ/WAIT/CAPTURE operations at Phase 9's
physically verified cadence. The buffer index now comes from the explicit
halfword counter, rather than subtracting a presumed pipeline latency.
Consecutive writes, byte masks, address mapping, loader firmware, CRC checking,
CPU/cache behavior, clocks, pins and SDC constraints are unchanged.

The longer refill needs a refresh reservation: refresh starts at timer 620
instead of 700, reserving 80 clocks for refill. The existing test still enforces
a 740-clock maximum interval (14.8 us), below the 15.625 us device deadline.
This is required by the conservative refill, not a relaxation of refresh.
Read performance falls; upload correctness takes priority over FPS.

## Verification

- Original RTL reproduces the precise +1-halfword failure under an empirical
  early-data/hold-last model derived from the physical CRC evidence. This mode
  is labeled as a fault model, not a vendor CL2 model.
- Corrected RTL passes the existing CL2 model and the empirical model, with
  open and closed rows, at four memory regions, with exact 512-byte CRCs.
- 16109 randomized lane/bank/row/refresh/reset transactions pass on the standard
  model; another 16109 per open/closed mode pass on the empirical model.
- CPU retirement/trap tests, 1024 RV32M vectors and cache coherence tests pass.
- Integrated CPU/SDRAM/palette/VGA: three complete frames, 1260000 checked
  pixels, zero underflows, maximum observed video wait 91 clocks.
- Complete real ROM-loader simulation checks all 94868 packets, both ELF CRCs,
  the full IWAD CRC and EXEC ACK. It stops at handoff and does not simulate DOOM.
- Quartus 13.0 SP1 synthesis, Fitter and slow/fast timing pass: 13529/18752 LEs,
  52/52 M4Ks; worst setup/hold +2.069/+0.215 ns. No timing exceptions weakened.
- Existing Phase 6–9 and original Phase 10 artifact/release bytes are checked
  against `reports/hotfix/preserved-releases.json`.

The old gameplay screenshot/boot report is historical and predates this fix.
No full DOOM run was repeated. New-controller physical upload and gameplay are
not claimed verified until the user programs this candidate and uploads.

Reproduce from repository root:

```sh
python3 phase10/tools/focused.py
python3 phase10/tools/test_upload_hotfix.py
python3 phase10/tools/integrated_fast.py
python3 phase10/tools/test_upload_integrated.py
sh phase10/quartus/build.sh
python3 phase10/tools/check_release.py snapshot
python3 phase10/tools/check_release.py
sh phase10/quartus/assemble_hotfix.sh
```

The source snapshot and upload log are the release gates. `reports/hotfix/`
contains the raw results, original synthesis/fit evidence, and the physical
probe cases. The new SOF has its own SHA256 file; older manifests are preserved.

## Manual hardware commands

```sh
cd <checkout>
python3 phase10/tools/check_release.py
(cd phase10/candidates && sha256sum -c doom_chromatix_160x100_block32_crcfix_DA000001_20261114T212632Z.sof.sha256)
export QUARTUS_64BIT=0
Q=<quartus-bin>
SOF=phase10/candidates/doom_chromatix_160x100_block32_crcfix_DA000001_20261114T212632Z.sof
# Manual action only: programs volatile FPGA SRAM, not Flash.
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' -o "p;$SOF@1"
python3 phase6/tools/upload.py --upload \
 --elf phase10/artifacts/doom-rv32im.elf --wad phase6/assets/doom1.wad \
 --out phase10/build/hardware-upload-crcfix.hex \
 --cable 'USB-Blaster [1-1]' --device '@1: EP2C(15|20) (0x020B30DD)'
```

SOF SHA256: `1eafc1a39f34c344912713b1fd0044b678f4a082069c6578385a67b3c0545178`.

Do not use the original non-`crcfix` Phase 10 SOF. Expect final output
`Uploaded and verified 94868 packets; entry handoff acknowledged.`
The original uploader checks each END's RESULT as well as its status; all three
expected CRCs above must pass. No FPGA programming was performed by the agent.
