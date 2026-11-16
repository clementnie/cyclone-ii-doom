VERILATOR ?= /tmp/phase6-verilator/usr/bin/verilator
export VERILATOR_ROOT ?= /tmp/phase6-verilator/usr/share/verilator
.PHONY: all engine cpu-sim
all: engine
engine:
	python3 build.py
	python3 verify_elf.py
	llvm-nm -n artifacts/doom-rv32i.elf > build/symbols.txt
build/cpu/Vcpu_top: sim/cpu_top.v sim/boot.cpp ../phase4/rtl/rv32i_cpu.v
	$(VERILATOR) --cc --exe --build -j 4 -MAKEFLAGS OPT_FAST=-O3 -Wno-fatal --top-module cpu_top --Mdir $(CURDIR)/build/cpu -CFLAGS '-O3' sim/cpu_top.v ../phase4/rtl/rv32i_cpu.v $(CURDIR)/sim/boot.cpp
cpu-sim: engine build/cpu/Vcpu_top
	cd .. && phase6/build/cpu/Vcpu_top phase6/artifacts/doom-rv32i.elf phase6/assets/doom1.wad phase6/build/symbols.txt 10000000000 50 > phase6/reports/cpu-boot.log 2>&1
.PHONY: loader
loader: firmware/boot.hex
build/loader.elf: firmware/loader.c firmware/crc32.h firmware/start.S firmware/link.ld
	mkdir -p build
	clang --target=riscv32-unknown-elf -march=rv32i -mabi=ilp32 -mno-relax -msmall-data-limit=0 -Os -ffreestanding -fno-builtin -nostdlib -Wall -Wextra -Werror -fuse-ld=lld -Wl,-T,firmware/link.ld,-Map,build/loader.map firmware/start.S firmware/loader.c -o $@
	llvm-size $@
firmware/boot.hex: build/loader.elf
	llvm-objcopy -O binary $< build/loader.bin
	python3 ../phase2/tools/bin_to_hex.py build/loader.bin $@
RTL = rtl/phase6_soc.v rtl/phase6_bus.v rtl/jtag_mailbox.v ../phase4b/rtl/framebuffer.v ../phase4b/rtl/sdram_arbiter.v ../phase4b/rtl/diagnostic_text.v ../phase4/rtl/sdram_controller.v ../phase4/rtl/rv32i_cpu.v ../phase2/rtl/onchip_memory.v ../phase2/rtl/vga_tiles.v ../phase2/rtl/diagnostic_font.v ../rtl/ps2_receiver.v ../rtl/ps2_scancode_decoder.v ../rtl/ps2_keyboard_mmio.v
build/full/Vfull_top: sim/full_top.v sim/full.cpp $(RTL)
	$(VERILATOR) --cc --exe --build -j 4 -MAKEFLAGS OPT_FAST=-O3 -Wno-fatal --top-module full_top --Mdir $(CURDIR)/build/full -CFLAGS '-O3' sim/full_top.v $(RTL) $(CURDIR)/sim/full.cpp
.PHONY: full-sim
full-sim: engine loader build/full/Vfull_top
	cd .. && python3 phase6/tools/upload.py > phase6/reports/upload-manifest.json
	cd .. && phase6/build/full/Vfull_top phase6/build/upload.hex > phase6/reports/full-boot.log 2>&1
.PHONY: loader-sim mailbox-test test
loader-sim: engine loader build/cpu/Vcpu_top
	cd .. && python3 phase6/tools/upload.py > phase6/reports/upload-manifest.json
	cd .. && phase6/build/cpu/Vcpu_top phase6/artifacts/doom-rv32i.elf phase6/assets/doom1.wad phase6/build/symbols.txt 10000000000 50 phase6/build/loader.bin phase6/build/upload.hex > phase6/reports/loader-boot.log 2>&1
	cp reports/cpu-boot.json reports/loader-boot.json
mailbox-test:
	mkdir -p build
	/tmp/de2-iverilog/usr/bin/iverilog -B /tmp/de2-iverilog/usr/lib/ivl -g2012 -s tb_mailbox -o build/tb_mailbox sim/tb_mailbox.sv rtl/jtag_mailbox.v
	/tmp/de2-iverilog/usr/bin/vvp build/tb_mailbox > reports/mailbox-test.log
test: engine loader build/cpu/Vcpu_top mailbox-test discovery-test
	cd .. && python3 phase6/tools/upload.py > phase6/reports/upload-manifest.json
	python3 tools/test_upload.py > reports/upload-tests.log 2>&1
	python3 tools/test_loader.py
	cd .. && tclsh phase6/tools/test_upload_tcl.tcl > phase6/reports/upload-tcl-test.log 2>&1

.PHONY: discovery-test
discovery-test:
	mkdir -p reports/hotfix-issp
	cd .. && tclsh phase6/tools/test_issp_discovery.tcl > phase6/reports/hotfix-issp/discovery-tests.log 2>&1
