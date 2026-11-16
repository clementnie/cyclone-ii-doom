# Troubleshooting

| Symptom | Check / action |
| --- | --- |
| No compatible ISSP instance | Enumerate cable/device names; Quartus 13 may return OOM6 for DOOM6. Use the bundled uploader/discovery Tcl, not a hardcoded instance index. |
| Upload END error 7 | CRC mismatch from actual SDRAM. Stop and restore the tested Phase 9 pair. Original Phase 10 block-read capture is faulty; never disable CRC. |
| Loader timeout / error 8 | Readback may retain an earlier CRC failure. Preserve ACK/RESULT and raw logs; check exact pair, cable and prior END results. |
| Black VGA / no engine handoff | Verify SRAM configuration, board pins, reset, ACKs and every ELF/IWAD CRC before debugging video. Check halt LED and counters. |
| Keyboard has no effect | Use native PS/2 or a PS/2-capable keyboard. Receiver does not initialize a USB keyboard. Enter is unsupported. |
| Corruption or underflows | Stop performance comparisons; inspect SDRAM/PLL timing, board markings and arbitration logs. Restore the released pair. |
| Source gate says changed | Use an untouched v0.1.0 checkout for historical verification; rebuilding with another compiler can change ELF bytes. New builds need their own validation. |
| Quartus will not run | Cyclone II requires a legacy supporting release; recorded tool is 32-bit Quartus II 13.0 SP1. Install host compatibility libraries appropriate to your distribution. |
| Simulator path missing | Run `tools/test-phase9.sh` with installed Icarus/Verilator on PATH; it stages the legacy paths under `/tmp`. |
| IWAD rejected | Loader reserves less than 4.5 MiB. Use your own authorized compatible small IWAD; no commercial full-size IWAD support is promised. |

For bug reports include the public commit, SOF/ELF SHA256, FPGA/board/memory
markings, compiler/Quartus versions and raw logs. Keep private paths and game data
out of reports. Never upload a WAD as a diagnostic attachment.
