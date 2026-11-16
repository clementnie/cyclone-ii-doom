#!/usr/bin/env python3
import pathlib,subprocess,sys
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
rtl=(P/'Makefile').read_text().split('RTL = ',1)[1].splitlines()[0].split()
rtl=[str((P/x).resolve()) for x in rtl]
for name,top,params in [('tb_framebuffer_soc','tb_framebuffer_soc',[]),('tb_keyboard','tb_keyboard',[]),('tb_mmio','tb_mmio',[])]:
 if len(sys.argv)>1 and name!=sys.argv[1]:continue
 if name=='tb_keyboard':
  subprocess.run([sys.executable,str(P/'tools/keyboard_fast.py')],check=True);print('PASS timed keyboard',flush=True);continue
 s=(R/'phase4b/sim'/f'{name}.sv').read_text().replace('phase4b_soc','phase9_soc').replace('phase4b_bus','phase9_bus').replace('dut(.clk',"dut(.jtag_source(480'b0),.jtag_probe(),.clk")
 out=P/'build'/f'{name}.sv';out.write_text(s)
 exe=P/'build'/top
 cmd=['/tmp/phase9-tools/usr/bin/iverilog','-B','/tmp/phase9-tools/usr/lib/ivl','-g2012','-s',top,'-o',str(exe),str(out),str(R/'phase4/sim/sdram_model.sv'),*rtl]
 with (P/'reports'/f'{name}.log').open('w') as log:
  subprocess.run(cmd,cwd=R/'phase4b',stdout=log,stderr=log,check=True)
  subprocess.run(['/tmp/phase9-tools/usr/bin/vvp',str(exe)],cwd=R/'phase4b',stdout=log,stderr=log,check=True)
 print('PASS',top,flush=True)
