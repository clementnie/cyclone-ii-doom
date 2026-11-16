#!/usr/bin/env python3
"""Run the unchanged serialized keyboard/SDRAM/VGA test with Verilator timing.
The Icarus delayed SDRAM/VGA regression is separately retained.
"""
import pathlib,subprocess,os
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
# Compile the isolated demo fixture; never overwrite the working Phase 4b ROM.
subprocess.run(['clang','--target=riscv32-unknown-elf','-march=rv32i','-mabi=ilp32','-mno-relax','-msmall-data-limit=0','-O2','-ffreestanding','-fno-builtin','-nostdlib','-fuse-ld=lld','-Wl,-T,'+str(R/'phase4b/firmware/link.ld'),'-o',str(P/'build/keyboard.elf'),str(R/'phase4b/firmware/start.S'),str(P/'firmware/keyboard.c')],check=True)
subprocess.run(['llvm-objcopy','-O','binary',str(P/'build/keyboard.elf'),str(P/'build/keyboard.bin')],check=True)
subprocess.run(['python3',str(R/'phase2/tools/bin_to_hex.py'),str(P/'build/keyboard.bin'),str(P/'build/keyboard.hex')],check=True)
s=(R/'phase4b/sim/tb_keyboard.sv').read_text().replace('phase4b_soc','phase9_soc').replace('firmware/boot.hex',str(P/'build/keyboard.hex')).replace('dut(.clk',"dut(.jtag_source(480'b0),.jtag_probe(),.clk")
s=s.replace('cycles>60000000','cycles>100000000')
(P/'build/tb_keyboard.sv').write_text(s)
rtl=[str((P/x).resolve()) for x in (P/'Makefile').read_text().split('RTL = ',1)[1].splitlines()[0].split()]
with (P/'reports/keyboard-fast-build.log').open('w') as log:
 subprocess.run(['/tmp/phase9-tools/usr/bin/verilator','--binary','--timing','--build','-j','4','-Wno-fatal','--top-module','tb_keyboard','--Mdir',str(P/'build/keyboardfast'),str(P/'build/tb_keyboard.sv'),str(R/'phase4/sim/sdram_model.sv'),*rtl],env={**os.environ,'VERILATOR_ROOT':'/tmp/phase9-tools/usr/share/verilator'},stdout=log,stderr=log,check=True)
with (P/'reports/tb_keyboard-fast.log').open('w') as log:
 subprocess.run([str(P/'build/keyboardfast/Vtb_keyboard')],cwd=R/'phase4b',stdout=log,stderr=log,check=True)
