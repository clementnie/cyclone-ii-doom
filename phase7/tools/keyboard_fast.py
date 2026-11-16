#!/usr/bin/env python3
"""Run the unchanged serialized keyboard/SDRAM/VGA test with Verilator timing.
The Icarus delayed SDRAM/VGA regression is separately retained.
"""
import pathlib,subprocess,os
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
s=(R/'phase4b/sim/tb_keyboard.sv').read_text().replace('phase4b_soc','phase7_soc').replace('dut(.clk',"dut(.jtag_source(480'b0),.jtag_probe(),.clk")
(P/'build/tb_keyboard.sv').write_text(s)
rtl=[str((P/x).resolve()) for x in (P/'Makefile').read_text().split('RTL = ',1)[1].splitlines()[0].split()]
with (P/'reports/keyboard-fast-build.log').open('w') as log:
 subprocess.run(['/tmp/phase6-verilator/usr/bin/verilator','--binary','--timing','--build','-j','4','-Wno-fatal','--top-module','tb_keyboard','--Mdir',str(P/'build/keyboardfast'),str(P/'build/tb_keyboard.sv'),str(R/'phase4/sim/sdram_model.sv'),*rtl],env={**os.environ,'VERILATOR_ROOT':'/tmp/phase6-verilator/usr/share/verilator'},stdout=log,stderr=log,check=True)
with (P/'reports/tb_keyboard-fast.log').open('w') as log:
 subprocess.run([str(P/'build/keyboardfast/Vtb_keyboard')],cwd=R/'phase4b',stdout=log,stderr=log,check=True)
