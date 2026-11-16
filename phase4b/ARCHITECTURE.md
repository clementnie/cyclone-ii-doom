# Phase 4B budget and map

50 MHz system logic; 25 MHz pixel enable, 800x525 raster, 640x480 visible.
SDRAM clock remains the physically tested PLL +8 ns (144 degree) output.
No asynchronous pixel clock domain: raster, palette, line buffers and arbiter
use 50 MHz with clock enables. Original SDRAM controller is unchanged.

320x200 INDEX8, doubled to 640x400 at y=40..439. Two 64 KiB buffer slots:
A 20000000..2000F9FF; B 20010000..2001F9FF (64,000 live bytes each).
The rest of SDRAM 20020000..207FFFFF is available for program/data/assets.
ROM and on-chip RAM retain the Phase 4 map and four byte-array optimization.

New video registers at 10006000 (aligned 32-bit accesses only):
+00 control bit0 enable; +04 requested buffer slot bit0; +08 status
(bit0 enabled, bit1 active slot, bit2 swap pending); +0c sticky underflows;
+10 completed scanout words; +14 completed CPU SDRAM requests;
+18 maximum display request-to-completion cycles; +1c active frame count;
+20 current output scanline (palette update window).
Palette at 10006400..100067ff: 256 x RGB444 values in bits11:0.
Buffer request is sampled only in vertical blank at y=520. CPU should render only to
the inactive slot and wait for status acknowledgement before reusing it.
Original video MMIO/tile diagnostic remains selected when framebuffer disabled.

Source row is fetched once and reused for two VGA rows. Line stores are two
80x32-bit simple dual-port RAMs (2 M4K total); palette 256x12 (1 M4K).
Baseline uses 38/52 M4Ks, expected total 41/52. No on-chip frame allocation.

Raster line duration 32us, source row duration64us =3200 system clocks.
80 SDRAM words per source row. Four display transactions then one waiting
CPU transaction, with explicit request-low rearm between grants. At a
conservative 30 cycles per grant plus periodic refresh, <=3100 cycles per
row with CPU continuously requesting. Refresh remains highest priority
inside the proven controller. Requests cannot be preempted once granted.
CPU starvation bound is four display grants plus refresh (<=160 clocks including its own completion).
Display wait is bounded by one CPU grant (<=80 clocks through completion), excluding power-up.
Initial row prefetch uses the top letterbox. Late rows output black and
increment sticky underflow; raster timing never stalls. Invalid line tags
are never displayed as current pixels.

Read bandwidth: 64,000 x59.524 =3.810 MB/s. The line buffer avoids fetching
repeated pixels/rows. Raw controller useful bandwidth is measured by tests;
it is not the 100 MB/s physical x16 bus rate. CPU rendering and DOOM FPS
must be measured separately. Pixel/palette pipeline is registered and its
sync/blank coordinates delayed alongside data.

Measured simulation with the final registered CPU response path:
three raster frames =50.4ms; 48,000 display words =3.810 MB/s;
35,984 concurrent CPU word stores =2.856 MB/s; aggregate useful throughput
6.665 MB/s. Display request maximum49 clocks. The independent saturated
arbiter test (22-cycle modeled memory plus refresh gaps) measures CPU/display
wait maxima136/54 clocks. These are simulation measurements, not new
physical SDRAM bandwidth measurements. Underflow is zero in both CPU image
and DG gradient tests. Forced DMA lateness/errors increment the counter.

Clock constraints and all 57 pin assignments are byte-for-byte/equivalent
to the physically tested Phase 4 set. Quartus infers41/52 M4Ks: the exact
three-block increase budgeted above. A registered CPU response cuts the
measured MMIO mux-to-register critical path, adding one CPU wait cycle;
it does not alter memory order or CPU instruction support.
