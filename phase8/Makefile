VERILATOR ?= /tmp/phase6-verilator/usr/bin/verilator
export VERILATOR_ROOT ?= /tmp/phase6-verilator/usr/share/verilator
RTL = rtl/phase8_soc.v rtl/phase8_bus.v rtl/phase8_mailbox.v rtl/instruction_cache.v rtl/performance.v ../phase4b/rtl/framebuffer.v rtl/phase8_sdram_arbiter.v ../phase4b/rtl/diagnostic_text.v rtl/phase8_sdram_controller.v ../phase4/rtl/rv32i_cpu.v ../phase2/rtl/onchip_memory.v ../phase2/rtl/vga_tiles.v ../phase2/rtl/diagnostic_font.v ../rtl/ps2_receiver.v ../rtl/ps2_scancode_decoder.v ../rtl/ps2_keyboard_mmio.v
build/full%/Vfull_top: sim/full.cpp sim/full_top.v $(RTL)
	$(VERILATOR) --cc --exe --build -j 4 -MAKEFLAGS OPT_FAST=-O3 -Wno-fatal --top-module full_top -GOPEN_PAGE=$* --Mdir $(CURDIR)/build/full$* -CFLAGS '-O3' sim/full_top.v $(RTL) $(CURDIR)/sim/full.cpp
