# Development and repository map

Phase directories retain their relative paths to keep tested source lists and
regressions intact. The public repository begins with a clean import; the original
Git repository, complete working tree and all FPGA releases remain privately
preserved. No original branches were rewritten.

| Location | Purpose |
| --- | --- |
| `rtl/`, `sim/` | Shared PS/2 logic and early tests |
| `phase2/` | RV32I, on-chip memory and diagnostics |
| `phase4/` | SDRAM controller and behavioral model |
| `phase4b/` | Framebuffer, shared VGA RTL, doomgeneric engine and headers |
| `phase5/vendor/` | Pinned compiler-rt source and license |
| `phase6/` | ROM loader, JTAG uploader, full bare-metal runtime |
| `phase7/`, `phase8/` | Instruction-cache baseline and open-row work |
| `phase9/` | Released RV32IM CPU, split caches, engine build and Quartus project |
| `phase10/` | Experimental selective renderer, block buffers and physical CRC repair |
| `tools/` | Publication verification and portable simulator setup |
| `docs/`, `releases/` | Technical guides, checksums and release provenance |

## Engineering milestones

Original private commit identifiers are recorded only as provenance; they are
not reachable commits in this clean public repository.

- `1108873`: initial checkpoint.
- `1347b03`: verified diagnostics before SDRAM work.
- `1757c49`, `d3f9b6f`: SDRAM and framebuffer/platform integration.
- `d11b7e9`: complete freestanding RV32I engine link.
- `6c2d959`, `46b63ce`: real E1M1 RTL execution and ROM/JTAG loader qualification.
- `10ddbf5`: Quartus four-byte ISSP instance discovery correction.
- `ebc7aa8`, `e5c905b`: coherent instruction cache and recorded Phase 7 hardware result.
- `8b91b7d`, `621cbac`: open-row SDRAM experiments and preserved baseline.
- `c0533ec`: Phase 9 RV32IM fetch overlap, split caches and timing-qualified pair.
- `af52b8b`: initial Phase 10 rendering/block-access candidate.
- Subsequent uncommitted Phase 10 changes: physical CRC diagnosis and isolated-read hotfix.

## Physical debugging

The initial Phase 10 32-byte read pipeline passed its digital model but failed
ELF CRC readback on hardware. Tests found each block transformed from halfwords
`h0 h1 … h15` into `h1 h2 … h15 h15`. Applying that transformation reproduced
the exact failed ELF CRC. The fix fills blocks with sixteen isolated READ/WAIT/
CAPTURE operations at Phase 9 cadence and advances refresh reservation.
See `phase10/HOTFIX.md` for raw evidence and limits: there is no electrical DQ
capture, and the corrected candidate has not been physically gameplay-verified.
CRC checks must remain enabled. The faulty original Phase 10 SOF is excluded.

ChromatiX-inspired adaptations include selective column/row sampling, skipped
plane work, neighbor-aware fuzz/wipe reconstruction, packed presentation,
32-byte lines and four buffered blocks. Attribution, source hashes and design
tradeoffs are retained in `phase10/RESEARCH.md` and `phase10/licenses/`.

## Future updates

1. Work on a branch in this public repository; keep WADs and build databases ignored.
2. Run focused CPU/cache/SDRAM and integrated VGA/loader tests, then fit/timing gates.
3. Record source hashes before fit; do not refresh a manifest merely to bypass a failure.
4. Give every SOF a unique filename. Preserve the previous tested SOF/ELF pair.
5. Manually validate upload CRCs, visuals, input and post-wipe performance on hardware.
6. Commit logs and a new manifest with tool versions, scene notes and SHA256 digests.
7. Audit all new commits, create a tag and publish matching assets plus complete source.
   Use a prerelease when physical validation is incomplete. Never mix Phase 9 firmware
   with an RV32I core or Phase 10 firmware with the older resolution registers.

An optional GitHub Actions workflow is provided as `docs/ci-example.yml`. Copy it
to `.github/workflows/verify.yml` using credentials with workflow permission to
enable CI. The initial publication token has repository access without that scope.
