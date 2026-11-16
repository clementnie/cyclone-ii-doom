# D4000001 physical SDRAM validation — user action required

No hardware validation has occurred. No programmer is run by these scripts.
The SOF is conditional on the PSC A2V64S40CTP-G7 device and retained DE1 /
Cyclone II Starter Board rev 1.1A wiring. The reported package text appears
to abbreviate this ordering code; reconcile it before programming.

1. Keep the known-good `phase2/releases/cyclone_ii_diagnostics_D1060001.sof`
   available for recovery. The new image has a separate filename.
2. Check `phase4/candidates/SHA256SUMS` from that directory. Confirm the
   target device is EP2C20F484C7 and the physical board matches the retained
   SDRAM wiring. This is DE1 / Cyclone II Starter Board, not DE1-SoC or DE2.
3. Manually load `reference_sdram_D4000001.sof` with Quartus Programmer.
   Use volatile FPGA configuration; do not overwrite board configuration
   Flash for this first test.
4. VGA should retain a stable 640x480 raster, with an SDRAM D4000001 banner,
   moving hardware refresh marker and independently changing VGA frame count.
   LEDR0 should be off. CPU HEARTBEAT should advance throughout memory tests.
5. TEST ADDRESS advances within 20000000–207FFFFC. ERROR COUNT stays zero.
   SDRAM initially reports TEST RUNNING, then PASS - FULL 8 MIB. Final test
   address is 207FFFFC; heartbeat and VGA frame count continue. Full sweeps
   can take minutes. Do not mistake an advancing address for a completed PASS.
6. On corruption: SDRAM reports FAIL, error code E400, with nonzero error
   count. Testing continues and final count remains visible. CPU traps set
   LEDR0 and the dashboard shows a CPU cause. Record the display before reset.
7. KEY0 should restart the diagnostic, including during an active sweep.
   Memory controller/refresh keep running while CPU/peripherals reset.
   The diagnostic does not consume keyboard events; typing has no required
   effect. Releasing KEY0 must return to TEST RUNNING and eventually PASS.
8. Repeat warm resets and multiple cold power/configuration cycles. Record
   time to PASS, final address/count, heartbeat, raster stability, reset
   behavior and any sensitivity to warm-up. A single successful pass is
   initial evidence, not proof of every electrical operating condition.

Send those results before framebuffer integration proceeds. Any FAIL or
hang blocks the SDRAM hardware milestone. The fallback is the preserved
D1060001 release; do not conceal errors by relaxing timing constraints.
