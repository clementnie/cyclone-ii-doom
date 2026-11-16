# Framebuffer physical test: D4B00001

No Phase 4B hardware result has been obtained. D4000001 remains the
physically tested SDRAM baseline. No programmer is invoked automatically.

1. Keep the exact D1060001 and D4000001 SOFs for recovery. Check the new
   candidate against `candidates/SHA256SUMS` from that directory.
2. Confirm EP2C20F484C7 and the same Starter Board/PSC -G7 configuration
   used for the successful D4000001 test. Pin assignments and SDRAM/VGA
   timing constraints are preserved exactly.
3. Manually configure the FPGA with
   `candidates/cyclone_ii_framebuffer_D4B00001.sof`. Use volatile FPGA
   configuration; do not overwrite board Flash for this test.
4. Expect the familiar diagnostic display briefly while firmware draws.
   Then expect the image in `reference.png`: top row of large red, green,
   blue, white and black regions; a black/white checkerboard; blue lower
   region with crossing yellow diagonals and a cyan moving rectangle.
   There are 40 black VGA lines above/below the 640x400 doubled image.
5. The lower-left fields are F (hardware frame count sampled for a CPU
   render), H (CPU heartbeat/render count) and red U (scanout underflow or
   DMA error count), each eight hexadecimal digits. F/H should advance;
   U must stay 00000000. Screen updates are limited by software drawing,
   not the 59.52 Hz monitor refresh. The reference shows the first image;
   rectangle/counter changes on the physical image are expected.
6. Hold arrow keys: Up/Down move the rectangle vertically in its lower
   blue region, Left/Right move it horizontally. With no arrow held it
   moves horizontally automatically. Input is polled once per render,
   so expect visible latency, not instantaneous response.
7. Press/release Escape to select the preserved diagnostic screen, then
   press/release it again to return to pixels. Diagnostic fields show CPU
   heartbeat, hardware frames, completed DMA words and error count.
8. KEY0 restarts CPU/video/firmware; the memory controller keeps refreshing.
   Expect drawing and animation to resume. VGA must retain stable timing.
9. Leave it running for several minutes, exercise keys/fallback/reset, and
   repeat cold configuration. Send a photo and report F/H progress, U,
   key behavior, raster stability and any flicker/blank/corrupted rows.

Any underflow, unexpected row, palette corruption or unstable sync blocks
physical framebuffer verification. Simulation and positive STA are not
physical evidence. The FPGA has not run DOOM in this iteration.
