export TMPDIR := $(CURDIR)/build
IVERILOG ?= /tmp/de2-iverilog/usr/bin/iverilog
VVP ?= /tmp/de2-iverilog/usr/bin/vvp
IVL_FLAGS ?= -B /tmp/de2-iverilog/usr/lib/ivl
.PHONY: test regression firmware
build:
	mkdir -p build
test: | build
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_sdram -o build/tb_sdram sim/tb_sdram.sv sim/sdram_model.sv rtl/sdram_controller.v
	$(VVP) build/tb_sdram
regression:
	$(MAKE) -C ../phase2 test
CLANG ?= clang
OBJCOPY ?= llvm-objcopy
CFLAGS = --target=riscv32-unknown-elf -march=rv32i -mabi=ilp32 -mno-relax -msmall-data-limit=0 -O2 -ffreestanding -fno-builtin -nostdlib -Wall -Wextra -Werror
firmware: firmware/boot.hex
build/boot.elf: firmware/start.S firmware/main.c firmware/link.ld | build
	$(CLANG) $(CFLAGS) -fuse-ld=lld -Wl,-T,firmware/link.ld,-Map,build/boot.map -o $@ firmware/start.S firmware/main.c
build/boot.bin: build/boot.elf
	$(OBJCOPY) -O binary $< $@
firmware/boot.hex: build/boot.bin
	python3 ../phase2/tools/bin_to_hex.py $< $@
SOC_RTL = rtl/phase4_soc.v rtl/phase4_bus.v rtl/sdram_controller.v rtl/diagnostic_text.v rtl/rv32i_cpu.v ../phase2/rtl/onchip_memory.v ../phase2/rtl/vga_tiles.v ../phase2/rtl/diagnostic_font.v ../rtl/ps2_receiver.v ../rtl/ps2_scancode_decoder.v ../rtl/ps2_keyboard_mmio.v
build/sim.elf: firmware/start.S firmware/main.c firmware/link.ld | build
	$(CLANG) $(CFLAGS) -DTEST_WORDS=32 -DSIMULATION_TEST_EXECUTE -fuse-ld=lld -Wl,-T,firmware/link.ld -o $@ firmware/start.S firmware/main.c
build/sim.hex: build/sim.elf
	$(OBJCOPY) -O binary $< build/sim.bin
	python3 ../phase2/tools/bin_to_hex.py build/sim.bin $@
.PHONY: soc-test
soc-test: build/sim.hex
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_soc -o build/tb_soc sim/tb_soc.sv sim/sdram_model.sv $(SOC_RTL)
	$(VVP) build/tb_soc
test: soc-test
.PHONY: audit quartus
audit:
	python3 tools/audit.py
quartus: firmware audit
	sh quartus/review.sh
	python3 tools/check_timing.py
.PHONY: candidate
candidate: quartus
	sh quartus/assemble.sh

.PHONY: cpu-test
cpu-test: | build
	$(MAKE) -C ../phase2 build/cpu_meta.vh
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -I../phase2/build -s tb_cpu -o build/tb_cpu ../phase2/sim/tb_cpu.sv rtl/rv32i_cpu.v
	cd ../phase2 && $(VVP) ../phase4/build/tb_cpu
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_traps -o build/tb_traps ../phase2/sim/tb_traps.sv rtl/rv32i_cpu.v
	$(VVP) build/tb_traps
test: cpu-test
.PHONY: compatibility-test
compatibility-test:
	$(MAKE) -C ../phase2 compile memory-test vga-test soc-test pins top-test dashboard-test ram-diagnostic-test starter-test RTL='rtl/de2_phase2.v rtl/onchip_memory.v rtl/phase2_soc.v ../phase4/rtl/rv32i_cpu.v rtl/soc_bus.v rtl/vga_tiles.v rtl/diagnostic_text.v rtl/diagnostic_font.v ../rtl/ps2_receiver.v ../rtl/ps2_scancode_decoder.v ../rtl/ps2_keyboard_mmio.v'
regression: compatibility-test
