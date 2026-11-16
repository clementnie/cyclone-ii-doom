# License, attribution and redistribution

Original project RTL, tools, firmware and documentation are made available under
GPL-2.0-or-later. See LICENSE. Existing third-party notices take precedence for
their respective files; no ownership of third-party work is claimed.

| Component | Origin / terms |
| --- | --- |
| DOOM engine and doomgeneric | id Software and doomgeneric contributors; GPL notices retained in `phase4b/doom/upstream/`; archive pin in `phase4b/doom/UPSTREAM.md` |
| LLVM compiler-rt | Apache-2.0 WITH LLVM-exception, plus historical terms retained in `phase5/vendor/compiler-rt/LICENSE.TXT`; source hashes in `SOURCE_SHA256.json` |
| Phase 10 renderer adaptations | DOOM GPL notices plus Enjoy-Digital / ChromatiX credits in `phase10/RESEARCH.md`; BSD-2-Clause text in `phase10/licenses/` |
| Quartus megafunctions/tools | Altera proprietary, separately installed; no implementation library is bundled |

Compiler-rt's LLVM exception addresses embedded compiled portions and conflicting
GPLv2 conditions; retain its full license with binary distributions. DOOM source
licensing does not grant redistribution rights to WAD game data. Users must
supply an authorized compatible IWAD. No WAD, WAD archive or extracted texture,
sound or game screenshot is distributed here. DOOM and Altera names identify
the software and hardware; this project is not endorsed by their owners.

The SOF targets an Altera device and contains synthesized project logic plus
Quartus-generated device configuration. Quartus tooling and megafunction
implementation source are not relicensed by this project. Source-level wrappers
instantiate `altpll` and `altsource_probe`; use requires separately obtained Altera tools.

## Publication exclusions

The private original is preserved outside this repository, including all old
SOFs/firmware. The public import excludes local IWAD copies and their distribution
archive, simulation game captures, vendor manuals/schematics/reference copies,
Quartus databases/output caches, host executables, temporary build/simulation
outputs, IDE workspace state, checkpoint archives and redundant binary releases.
Only the Phase 9 tested pair and Phase 7 rollback pair are carried forward.
Original author email metadata is not imported. Ordinary build paths embedded in the exact tested ELFs are retained with the owner’s explicit approval.
Raw reports have host paths redacted; source hash manifests refer to source bytes,
not report presentation. Historical phase READMEs describe their state at the time
and may refer to deliberately excluded artifacts. The current guides define the
supported release workflow.
