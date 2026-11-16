IVERILOG ?= iverilog
VVP ?= vvp
IVL_FLAGS ?=
BUILD_DIR ?= /tmp/de2-ps2-sim
RTL := ../rtl/ps2_receiver.v ../rtl/ps2_scancode_decoder.v ../rtl/ps2_keyboard_mmio.v

.PHONY: test compile-rtl

test: compile-rtl
	mkdir -p $(BUILD_DIR)
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_ps2_keyboard -Ptb_ps2_keyboard.CLK_HZ=25000000 -o $(BUILD_DIR)/ps2-25 tb_ps2_keyboard.sv $(RTL)
	$(VVP) $(BUILD_DIR)/ps2-25
	$(IVERILOG) $(IVL_FLAGS) -g2012 -Wall -s tb_ps2_keyboard -Ptb_ps2_keyboard.CLK_HZ=50000000 -o $(BUILD_DIR)/ps2-50 tb_ps2_keyboard.sv $(RTL)
	$(VVP) $(BUILD_DIR)/ps2-50

compile-rtl:
	$(IVERILOG) $(IVL_FLAGS) -g2005 -Wall -tnull -s ps2_keyboard_mmio $(RTL)
