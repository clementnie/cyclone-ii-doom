# Performance evidence

| Configuration | Measurement type | FPS | Scope |
| --- | --- | ---: | --- |
| Phase 7 | Physical, recorded during development | 0.815 | Historical baseline; see `phase8/baseline/HARDWARE.md` |
| Phase 9 | Physical, user-captured JTAG counters | 2.446766 | 118 presentation frames in 48.22692122 seconds |
| Phase 10 original | Startup simulation | approximately 5.41 | Opening sequence; not steady gameplay or hardware |
| Phase 10 CRC hotfix | Physical gameplay | unknown | Pending validation |

Phase 9 raw inputs are `phase9/reports/hardware-A.txt` and `hardware-B.txt`.
The publication process reproduced the arithmetic, without reacquiring the board:

```sh
python3 phase9/tools/analyze_hardware.py phase9/reports/hardware-A.txt phase9/reports/hardware-B.txt
```

At 50 MHz, unsigned counter deltas are `(after - before) & 0xffffffff`.
The measured delta is 2,411,346,061 cycles, 147,743,421 retired instructions,
118 frames and zero underflows. FPS = 50,000,000 × frames / cycles; CPI = 16.3212.
The two captures are under 60 seconds apart and the cycle counter wraps once.
These are user-captured physical logs; acquisition was not independently verified.
The scene was identified as E1M1 during development; a synchronized video was
not supplied, so scene stability cannot be independently reconstructed.

For new measurements, wait for the opening melt and weapon rise, hold the same
E1M1 view, then capture at least three pairs 20 seconds apart without reset:

```sh
"$QUARTUS_BIN/quartus_stp" -t phase9/tools/profile.tcl "$CABLE" "$DEVICE" > /tmp/doom-before.txt
sleep 20
"$QUARTUS_BIN/quartus_stp" -t phase9/tools/profile.tcl "$CABLE" "$DEVICE" > /tmp/doom-after.txt
python3 phase9/tools/analyze_hardware.py /tmp/doom-before.txt /tmp/doom-after.txt
```

Keep raw logs, scene/input notes and image hashes. Record movement/shooting
separately. Presentation counts include wipe frames, so startup is unsuitable
for steady-gameplay benchmarking. The display raster refresh rate is not engine FPS.
Stall counters overlap and must not be added as a CPI decomposition. Legacy
fixed-PC counters do not identify arithmetic helpers in relocated firmware.

Phase 9's bounded simulation ran three real engine frames with zero underflows;
that opening-sequence result is a correctness check. Historical reports saying
`physical_test: NOT PERFORMED` predate the later user-captured hardware logs.

15–20 FPS and later 20 FPS discussions are engineering targets. No 20–30 FPS
physical result exists in the audited tree. ChromatiX measurements belong to
that different machine. The old Phase 10 5.41 FPS simulation predates its CRC
hotfix, whose conservative read cadence may reduce performance.
