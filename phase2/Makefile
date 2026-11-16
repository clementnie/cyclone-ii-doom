export TMPDIR := $(CURDIR)/build
CLANG ?= clang
OBJCOPY ?= llvm-objcopy
IVERILOG ?= $(shell command -v iverilog 2>/dev/null || echo /tmp/de2-iverilog/usr/bin/iverilog)
VVP ?= $(shell command -v vvp 2>/dev/null || echo /tmp/de2-iverilog/usr/bin/vvp)
IVL_FLAGS ?= $(if $(filter /tmp/de2-iverilog/%,$(IVERILOG)),-B /tmp/de2-iverilog/usr/lib/ivl,)
CFLAGS = --target=riscv32-unknown-elf -march=rv32i -mabi=ilp32 -mno-relax -msmall-data-limit=0 -O2 -ffreestanding -fno-builtin -nostdlib -Wall -Wextra -Werror
RTL = $(wildcard rtl/*.v) ../rtl/ps2_receiver.v ../rtl/ps2_scancode_decoder.v ../rtl/ps2_keyboard_mmio.v
.PHONY: firmware test compile pins quartus cpu-test memory-test vga-test soc-test ps2-test top-test
firmware: firmware/boot.hex
build:
	mkdir -p build
build/boot.elf: firmware/start.S firmware/main.c firmware/link.ld | build
	$(CLANG) $(CFLAGS) -fuse-ld=lld -Wl,-T,firmware/link.ld,-Map,build/boot.map -o $@ firmware/start.S firmware/main.c
build/boot.bin: build/boot.elf
	$(OBJCOPY) -O binary $< $@
firmware/boot.hex: build/boot.bin tools/bin_to_hex.py
	python3 tools/bin_to_hex.py $< $@
compile: firmware
	$(IVERILOG) $(IVL_FLAGS) -g2005 -Wall -tnull -s de2_phase2 $(RTL)
quartus: firmware pins
	cd quartus && quartus_sh --flow compile de2_phase2

build/cpu_meta.vh: tools/cpu_vectors.py | build
	python3 tools/cpu_vectors.py
cpu-test: build/cpu_meta.vh
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -Ibuild -s tb_cpu -o build/tb_cpu sim/tb_cpu.sv rtl/rv32i_cpu.v
	$(VVP) build/tb_cpu
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_traps -o build/tb_traps sim/tb_traps.sv rtl/rv32i_cpu.v
	$(VVP) build/tb_traps

memory-test: firmware
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_memory -o build/tb_memory sim/tb_memory.sv $(RTL)
	$(VVP) build/tb_memory
vga-test: | build
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_vga -o build/tb_vga sim/tb_vga.sv rtl/vga_tiles.v rtl/diagnostic_text.v rtl/diagnostic_font.v
	$(VVP) build/tb_vga
soc-test: firmware
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_soc -o build/tb_soc sim/tb_soc.sv $(RTL)
	$(VVP) build/tb_soc
ps2-test: | build
	$(MAKE) -C ../sim test IVERILOG=$(IVERILOG) VVP=$(VVP) IVL_FLAGS='$(IVL_FLAGS)' BUILD_DIR=$(CURDIR)/build/ps2

test: compile cpu-test memory-test vga-test soc-test ps2-test pins

pins: firmware
	python3 tools/check_project.py

top-test: firmware
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_top -o build/tb_top sim/tb_top.sv $(RTL)
	cd quartus && $(VVP) ../build/tb_top

test: top-test

.PHONY: dashboard-test ram-diagnostic-test starter-test
ram-diagnostic-test: firmware
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_ram_diagnostic -o build/tb_ram_diagnostic sim/tb_ram_diagnostic.sv $(RTL)
	$(VVP) build/tb_ram_diagnostic

dashboard-test: | build
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_dashboard -o build/tb_dashboard sim/tb_dashboard.sv rtl/vga_tiles.v rtl/diagnostic_text.v rtl/diagnostic_font.v
	$(VVP) build/tb_dashboard

starter-test: firmware
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_starter -o build/tb_starter quartus_ep2c20/tb_starter.sv quartus_ep2c20/starter_phase2.v $(RTL)
	cd quartus_ep2c20 && $(VVP) ../build/tb_starter

test: dashboard-test ram-diagnostic-test starter-test
