#!/usr/bin/env python3
"""Run the inherited pixel-by-pixel integrated SoC regression with timed Verilator."""
import pathlib,subprocess,os
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
s=(R/'phase4b/sim/tb_framebuffer_soc.sv').read_text().replace('phase4b_soc','phase10_soc').replace('dut(.clk',"dut(.jtag_source(480'b0),.jtag_probe(),.clk")
(P/'build/tb_framebuffer_soc-final.sv').write_text(s)
rtl=[str((P/x).resolve()) for x in (P/'Makefile').read_text().split('RTL = ',1)[1].splitlines()[0].split()]
with (P/'reports/integrated-build.log').open('w') as log:
 subprocess.run(['/tmp/phase9-tools/usr/bin/verilator','--binary','--timing','--build','-j','4','-Wno-fatal','--top-module','tb_framebuffer_soc','--Mdir',str(P/'build/integrated'),str(P/'build/tb_framebuffer_soc-final.sv'),str(P/'sim/sdram_model.sv'),*rtl],env={**os.environ,'VERILATOR_ROOT':'/tmp/phase9-tools/usr/share/verilator'},stdout=log,stderr=log,check=True)
with (P/'reports/tb_framebuffer_soc.log').open('w') as log:
 subprocess.run([str(P/'build/integrated/Vtb_framebuffer_soc')],cwd=R/'phase4b',stdout=log,stderr=log,check=True)
print((P/'reports/tb_framebuffer_soc.log').read_text())
