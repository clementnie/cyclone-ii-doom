# Publication audit — v0.1.0

The original repository remains intact. A full working-tree archive and an
all-ref Git bundle were created outside the publication repository before editing.
All existing SOFs and firmware were preserved; no FPGA or Flash programming and
no Quartus rebuild occurred during publication.

The audit examined 1,679 reachable Git objects and 4,824 working files, including
the checkpoint archive contents. No private-key, GitHub-token or AWS access-key
patterns were found. This pattern scan was supplemented by inspection of source,
licenses, binary types, large objects, build paths and release evidence. The two
local WAD copies and their game distribution material were excluded. No WAD blob
was identified in reachable Git history. Generated databases, vendor reference
PDFs, simulation game images and old archives were excluded rather than copied
into public history. The original private author email is not in public metadata.

The public repository has a clean initial history and a GitHub noreply author.
The owner explicitly authorized retaining ordinary local source paths embedded
in the exact tested ELFs. Reports redact host paths. Neither secrets nor game
data are permitted by this exception. Third-party copyright/contact notices are
preserved. The source snapshots for doomgeneric and compiler-rt verify unchanged.

Validation performed for publication:

- Historical Phase 9 source/ELF, simulation, fit and timing gate.
- CPU: 507 retirement states, every register and PC, randomized bus stalls.
- Traps: 16 cases. RV32M: 1,024 directed/random arithmetic vectors.
- Cache coherence, errors, bypass, reset and backpressure.
- SDRAM: 16,109 mixed randomized accesses and 2,048 sequential requests.
- Timed integrated VGA: three frames / 1,260,000 checked pixels, zero underflows.
- Integrated MMIO and keyboard tests; results in Phase 9 reports.
- Isolated byte-identical ELF rebuild using the original diagnostic filename prefix.
- Physical-log arithmetic: 118 frames / 48.22692122 s = 2.446766 FPS.
- Tracked-file credential/WAD checks, upstream/source/artifact hashes and new guide links.

The released Phase 9 pair is unchanged from the supplied physical baseline.
Physical acquisition was not independently repeated. Phase 10 is experimental;
its original CRC failure and unverified hotfix are documented. Generated test
ROMs live only in ignored build directories. No WAD was needed for the fresh
publication regressions. Existing historical engine reports were audited, not
misrepresented as a new full engine simulation.
