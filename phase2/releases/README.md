# Offline FPGA images

- `cyclone_ii_diagnostics_D1060001.sof`: new diagnostic dashboard,
  EP2C20F484C7 (ordering code EP2C20F484C7N), Starter Board four-bit VGA.
- `original_pre_dashboard.sof`: exact pre-change color-demo image from the
  recoverable checkpoint.

Check integrity from this directory with `sha256sum -c SHA256SUMS`.
The normal Quartus full flow ran its unchanged pre-flow hook and verified
assembly for the exact device. See [build/test/timing results](../quartus_ep2c20/RESULTS.md)
and [diagnostic meanings and limits](../DIAGNOSTICS.md).
No physical FPGA programming was performed. Physical board/electrical review
is separate from offline compilation and simulation.
