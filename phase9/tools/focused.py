#!/usr/bin/env python3
"""Focused CPU/cache/controller regression; no DOOM boot."""
import pathlib, subprocess, random
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
subprocess.run(['python3',str(P/'tools/gen_m_vectors.py')],check=True)
IV='/tmp/phase9-tools/usr/bin/iverilog'; VV='/tmp/phase9-tools/usr/bin/vvp'
def test(name,sources,top=None,cwd=R,extra=()):
 exe=P/'build'/name
 with (P/'reports'/f'{name}.log').open('w') as log:
  subprocess.run([IV,'-B','/tmp/phase9-tools/usr/lib/ivl','-g2012',*extra,'-s',top or name,'-o',str(exe),*[str(R/s) for s in sources]],stdout=log,stderr=log,check=True)
  subprocess.run([VV,str(exe)],cwd=cwd,stdout=log,stderr=log,check=True)
 print((P/'reports'/f'{name}.log').read_text().strip())
test('tb_cpu',['phase2/sim/tb_cpu.sv','phase9/rtl/rv32i_cpu.v'],cwd=R/'phase2',extra=['-I'+str(R/'phase2/build')])
test('tb_traps',['phase9/sim/tb_traps.sv','phase9/rtl/rv32i_cpu.v'])
test('tb_cache',['phase9/sim/tb_cache.sv','phase9/rtl/instruction_cache.v'])
test('tb_m',['phase9/sim/tb_m.sv','phase9/rtl/rv32i_cpu.v'])
test('tb_sdram',['phase9/sim/tb_sdram.sv','phase4/sim/sdram_model.sv','phase9/rtl/phase9_sdram_controller.v'])
