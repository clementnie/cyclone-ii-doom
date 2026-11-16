export TMPDIR := $(CURDIR)/build
IVERILOG ?= /tmp/de2-iverilog/usr/bin/iverilog
VVP ?= /tmp/de2-iverilog/usr/bin/vvp
IVL_FLAGS ?= -B /tmp/de2-iverilog/usr/lib/ivl
CLANG ?= clang
OBJCOPY ?= llvm-objcopy
CFLAGS = --target=riscv32-unknown-elf -march=rv32i -mabi=ilp32 -mno-relax -msmall-data-limit=0 -O2 -ffreestanding -fno-builtin -nostdlib -Wall -Wextra -Werror
RTL = rtl/phase4b_soc.v rtl/phase4b_bus.v rtl/framebuffer.v rtl/sdram_arbiter.v rtl/diagnostic_text.v ../phase4/rtl/sdram_controller.v ../phase4/rtl/rv32i_cpu.v ../phase2/rtl/onchip_memory.v ../phase2/rtl/vga_tiles.v ../phase2/rtl/diagnostic_font.v ../rtl/ps2_receiver.v ../rtl/ps2_scancode_decoder.v ../rtl/ps2_keyboard_mmio.v
.PHONY: firmware test regression
build:
	mkdir -p build
firmware: firmware/boot.hex
build/boot.elf: firmware/start.S firmware/main.c firmware/link.ld | build
	$(CLANG) $(CFLAGS) -fuse-ld=lld -Wl,-T,firmware/link.ld,-Map,build/boot.map -o $@ firmware/start.S firmware/main.c
build/boot.bin: build/boot.elf
	$(OBJCOPY) -O binary $< $@
firmware/boot.hex: build/boot.bin
	python3 ../phase2/tools/bin_to_hex.py $< $@
build/sim.elf: firmware/start.S firmware/main.c firmware/link.ld | build
	$(CLANG) $(CFLAGS) -DSIM_STATIC_IMAGE -fuse-ld=lld -Wl,-T,firmware/link.ld -o $@ firmware/start.S firmware/main.c
build/sim.hex: build/sim.elf
	$(OBJCOPY) -O binary $< build/sim.bin
	python3 ../phase2/tools/bin_to_hex.py build/sim.bin $@
regression:
	$(MAKE) -C ../phase4 test regression
.PHONY: soc-test
soc-test: build/sim.hex
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_framebuffer_soc -o build/tb_soc sim/tb_framebuffer_soc.sv ../phase4/sim/sdram_model.sv $(RTL)
	$(VVP) build/tb_soc
test: soc-test
.PHONY: scanout-test
scanout-test: | build
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_scanout -o build/tb_scanout sim/tb_scanout.sv rtl/framebuffer.v
	$(VVP) build/tb_scanout
test: scanout-test
.PHONY: platform-test
platform-test: | build
	$(MAKE) -C doom platform-test
	$(OBJCOPY) -O binary doom/build/platform-test.elf build/platform.bin
	python3 ../phase2/tools/bin_to_hex.py build/platform.bin build/platform.hex
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_framebuffer_soc -Ptb_framebuffer_soc.PLATFORM=1 -o build/tb_platform sim/tb_framebuffer_soc.sv ../phase4/sim/sdram_model.sv $(RTL)
	$(VVP) build/tb_platform
.PHONY: arbiter-test
arbiter-test: | build
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_arbiter -o build/tb_arbiter sim/tb_arbiter.sv rtl/sdram_arbiter.v
	$(VVP) build/tb_arbiter
test: arbiter-test
.PHONY: keyboard-test
keyboard-test: firmware
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_keyboard -o build/tb_keyboard sim/tb_keyboard.sv ../phase4/sim/sdram_model.sv $(RTL)
	$(VVP) build/tb_keyboard
test: keyboard-test
.PHONY: audit quartus candidate doom-test
audit:
	python3 tools/audit.py
quartus: firmware audit
	sh quartus/review.sh
candidate: quartus
	sh quartus/assemble.sh
doom-test:
	$(MAKE) -C doom all
test: platform-test
.PHONY: mmio-test
mmio-test: firmware
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_mmio -o build/tb_mmio sim/tb_mmio.sv $(RTL)
	$(VVP) build/tb_mmio
test: mmio-test

test:
	python3 tools/test_manifest.py snapshot
.PHONY: native-tests
native-tests:
	$(MAKE) -C doom native-tests
test: native-tests
