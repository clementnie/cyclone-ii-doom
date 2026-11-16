# DOOM6 physical ISSP discovery hotfix

Checkpoint before this fix: `46b63ce`. No replacement SOF is needed.

Physical read-only enumeration returned the complete raw value:

```tcl
{0 480 96 OOM6}
```

The original parser used the correct `{index source_width probe_width name}`
field order, index and widths. Its five-character identity assumption was
wrong. Quartus 13's installed `altsource_probe_body.vhd` defines
`INSTANCE_ID_LENGTH = 4 * BYTE` (line 621); `serialize_instance_id` (lines
812–828) visits the string backwards and stops after four characters.
Therefore RTL `instance_id("DOOM6")` is serialized as **OOM6**. The physical
result confirms the hub and mailbox exist; there is no evidence of stale
metadata or omitted hardware. Synthesis also records DOOM6, 480/96 and the
instance-ID ROM. The earlier test stub incorrectly returned the full name.

The shared `issp_discovery.tcl` validates the exact known wire identity
`OOM6` (or literal `DOOM6`), exact 480/96 widths, the selected device ID
0x020B30DD, valid metadata and a unique matching instance. It discovers the
index; optional `--index N` restricts selection without bypassing checks.
Unknown identities, swapped fields/widths, malformed records and ambiguous
instances fail before session/source access. There is no suffix wildcard or
width-only fallback. The uploader explicitly selects 32-bit Quartus tools.

Read-only verification, safe to run before authorizing upload:

```sh
export QUARTUS_64BIT=0
Q=<quartus-bin>
"$Q/quartus_stp" -t phase6/tools/list_jtag.tcl \
  'USB-Blaster [1-1]' '@1: EP2C(15|20) (0x020B30DD)'
```

Expected: raw `{0 480 96 OOM6}` followed by `Verified DOOM6 mailbox` with
index 0, source 480, probe 96, reported_id OOM6. This only enumerates metadata;
it never starts a source/probe session or writes sources.

After explicit authorization, the next hardware action is:

```sh
set -o pipefail
python3 phase6/tools/upload.py --upload \
  --cable 'USB-Blaster [1-1]' \
  --device '@1: EP2C(15|20) (0x020B30DD)' \
  2>&1 | tee phase6/reports/hotfix-issp/physical-upload.log
```

This command writes FPGA SDRAM and then requests the real engine entry
handoff. It does not program configuration or Flash. It must not be run as
part of read-only verification. Every packet waits for matching ACK; every
END verifies the returned SDRAM readback CRC. Successful completion prints
`Uploaded and verified 92693 packets; entry handoff acknowledged. Observe VGA.`
Any rejection, CRC mismatch or timeout exits with an error; `pipefail`
preserves that failure through `tee`. Expected region CRC32 values are
`dde33c49`, `274b386d`, and IWAD `162b696a` in `upload-manifest.json`.
An acknowledged handoff is not evidence of a rendered physical frame.

The existing SOF is already programmed according to the hardware report.
Only if it later needs reprogramming, and only after authorization:

```sh
"$Q/quartus_pgm" -m jtag -c 'USB-Blaster [1-1]' \
  -o 'p;phase6/candidates/cyclone_ii_doom_D6000001_20261114T073201Z_d51a123a8b48.sof@1'
```

For first-frame confirmation, observe the actual E1M1 room and HUD on VGA,
then the pistol as its animation progresses. The full-SoC model took about
67 seconds after handoff for its first submitted frame, with a slow opening
melt; physical timing remains unmeasured. Report the upload exit status,
final D6/E6/E5 diagnostic, LEDR0, VGA photograph and arrow/Ctrl/Space response.
Do not reset the board automatically during discovery or verification.

Verification:

```sh
make -C phase6 test
make -C phase6 loader-sim
PHASE6_TCL_ALL=1 "$Q/quartus_stp" -t phase6/tools/test_upload_tcl.tcl
"$Q/quartus_stp" -t phase6/tools/test_issp_discovery.tcl
python3 phase6/tools/verify_issp_hotfix.py
```

Reports are in `reports/hotfix-issp/`: raw physical enumeration, corrected
physical selection, 29 discovery/safety cases, and all 92,693 upload packets
with stub transport in Quartus Tcl for both identity representations at
nonzero index 7. Phase 6 regression covers Python packet/CRC validation,
actual CPU/ROM error and timeout tests, and mailbox RTL. A fresh loader
simulation must reach 50 E1M1 engine frames. Stub tests perform no hardware
writes and do not establish physical ACK/CRC behavior.

`verify_issp_hotfix.py` checks every original implementation hash against
46b63ce's manifest, permitting only the reviewed host scripts/test Makefile
to differ. It checks byte-identical SOF, original full-SoC proof and fitted
timing reports, positive slack and no ignored critical assignments. The
original build manifest is preserved, not refreshed to disguise old proof
as a new hardware build. No RTL, ROM firmware, engine ELF, QSF or SDC changes
were needed, so synthesis/Fitter/TimeQuest and the 16-minute full SoC run
are not repeated. Physical upload, boot and gameplay still require approval
and observed results.
