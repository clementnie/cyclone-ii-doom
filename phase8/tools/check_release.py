#!/usr/bin/env python3
import pathlib,json,hashlib,re,sys
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
files=[*P.glob('rtl/*.v'),*P.glob('sim/*'),*P.glob('quartus/*.qsf'),*P.glob('quartus/*.sdc'),P/'artifacts/doom-rv32i.elf',R/'phase6/firmware/boot.hex',R/'phase4/rtl/rv32i_cpu.v']
files+=list((R/'phase4b/rtl').glob('*.v'))+list((R/'phase2/rtl').glob('*.v'))+list((R/'rtl').glob('ps2*.v'))
current={str(f.relative_to(R)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(files)}
if len(sys.argv)>1 and sys.argv[1]=='snapshot':
 (P/'reports/build-sources.json').write_text(json.dumps(current,indent=2)+'\n');exit()
assert current==json.loads((P/'reports/build-sources.json').read_text()),'sources changed'
assert (P/'artifacts/doom-rv32i.elf').read_bytes()==(P/'baseline/doom-rv32i.elf').read_bytes()
for variant in ['closed','openrow']:
 r=json.loads((P/f'reports/{variant}-boot.json').read_text());assert r['pass'] and r['underflows']==0
for name in ['cache-test.log','performance-test.log','profile-host-test.log','sdram-open.log','sdram-closed.log','upload-tests.log','loader-tests.log']:
 t=(P/'reports'/name).read_text();assert 'PASS' in t and 'FATAL' not in t,name
for name in ['tb_framebuffer_soc.log','tb_keyboard-fast.log','tb_mmio.log']:
 t=(P/'reports'/name).read_text();assert 'PASS' in t and 'FATAL' not in t,name
assert "make: Leaving directory" in (P/'reports/baseline-regressions.log').read_text()
result={}
for prefix in ['']:
 for c in ['slow','fast']:
  for part in ['','-sdram-in','-sdram-out']:
   for k in ['setup','hold']:
    key=f'{prefix}{c}{part}-{k}'
    t=(P/f'reports/{key}.txt').read_text();m=re.search(r'Worst case slack is ([-\d.]+)',t);assert m,key
    result[key]=float(m[1]);assert result[key]>0,key
 t=(P/f'reports/{prefix}check-timing.txt').read_text()
 for issue in ['no_clock','generated_clock','loops','latches']:
  assert re.search(r';\s*'+issue+r'\s*;\s*0\s*;',t),issue
 u=(P/f'reports/{prefix}unconstrained.txt').read_text();assert not re.search(r';\s*DRAM_(?!CLK)',u)
 log=(P/f'reports/{prefix}timing.log').read_text();assert not re.search(r'Ignored|could not be matched|Warning \(332',log)
 fit=(P/f'reports/{prefix}fitting.log').read_text();assert 'was successful' in fit and 'Warning (171167)' not in fit
assert (P/'quartus/phase8.sdc').read_bytes()==(R/'phase7/quartus/phase7.sdc').read_bytes(),'timing constraints changed'
assert (P/'rtl/instruction_cache.v').read_bytes()==(R/'phase7/rtl/instruction_cache.v').read_bytes(),'I-cache changed'
q=(P/'quartus/phase8.qsf').read_text();old=(R/'phase7/quartus/phase7.qsf').read_text()
assert [x for x in q.splitlines() if 'set_location_assignment' in x]==[x for x in old.splitlines() if 'set_location_assignment' in x],'pin assignments changed'
assert 'DEVICE EP2C20F484C7' in q
fitreport=(P/'reports/phase8.fit.rpt').read_text();assert re.search(r'M4Ks\s*;\s*52 / 52',fitreport)
(P/'reports/timing-summary.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS Phase8 release gates: coherent cache, profiling, complete regressions, actual DOOM/VGA, open-row SDRAM, unchanged pins/constraints and fitted timing')
