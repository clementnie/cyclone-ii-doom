#!/usr/bin/env python3
"""Timed Verilator runs of inherited framebuffer, keyboard and MMIO fixtures."""
import pathlib,subprocess,os
R=pathlib.Path(__file__).resolve().parents[1];P=R/'phase9'
rtl=[str((P/x).resolve()) for x in (P/'Makefile').read_text().split('RTL = ',1)[1].splitlines()[0].split()]
for name in ['tb_framebuffer_soc','tb_mmio']:
 s=(R/'phase4b/sim'/f'{name}.sv').read_text().replace('phase4b_soc','phase9_soc').replace('phase4b_bus','phase9_bus').replace('dut(.clk',"dut(.jtag_source(480'b0),.jtag_probe(),.clk")
 f=P/'build'/f'{name}-timed.sv';f.write_text(s);out=P/'build'/f'{name}-timed'
 with (P/'reports'/f'{name}-timed-build.log').open('w') as log:
  subprocess.run(['/tmp/phase9-tools/usr/bin/verilator','--binary','--timing','--build','-j','4','-Wno-fatal','--top-module',name,'--Mdir',str(out),str(f),str(R/'phase4/sim/sdram_model.sv'),*rtl],stdout=log,stderr=log,check=True,env={**os.environ,'VERILATOR_ROOT':'/tmp/phase9-tools/usr/share/verilator'})
 with (P/'reports'/f'{name}.log').open('w') as log:
  subprocess.run([str(out/f'V{name}')],cwd=R/'phase4b',stdout=log,stderr=log,check=True)
 print((P/'reports'/f'{name}.log').read_text(),flush=True)
subprocess.run(['python3',str(P/'tools/keyboard_fast.py')],check=True)
