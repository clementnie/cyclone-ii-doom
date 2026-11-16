#!/usr/bin/env python3
"""Fail closed: exact Phase 9 source/ELF hashes, simulation, fit and timing."""
import pathlib, json, hashlib, re, sys
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
files=[*P.glob('rtl/*.v'),*P.glob('sim/*'),*P.glob('quartus/*.qsf'),*P.glob('quartus/*.sdc'),P/'artifacts/doom-rv32im.elf',R/'phase6/firmware/boot.hex']
files += [*P.glob('*.c'),*P.glob('*.S'),*P.glob('*.ld'),*P.glob('runtime/*.c'),*P.glob('firmware/*'),P/'build.py']
files+=list((R/'phase4b/rtl').glob('*.v'))+list((R/'phase2/rtl').glob('*.v'))+list((R/'rtl').glob('ps2*.v'))
current={str(f.relative_to(R)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(files) if f.is_file()}
if sys.argv[1:] == ['snapshot']:
 (P/'reports/build-sources.json').write_text(json.dumps(current,indent=2)+'\n');sys.exit()
assert current==json.loads((P/'reports/build-sources.json').read_text()),'source/ELF changed'
for name in ['runtime-test','tb_cpu','tb_traps','tb_m','tb_cache','tb_sdram','tb_framebuffer_soc','tb_keyboard-fast','tb_mmio']:
 t=(P/f'reports/{name}.log').read_text();assert 'PASS' in t and 'FATAL' not in t,name
r=json.loads((P/'reports/phase9-boot.json').read_text());assert r['pass'] and r['frames']>=3 and r['underflows']==0
result={}
for c in ['slow','fast']:
 for part in ['','-sdram-in','-sdram-out']:
  for k in ['setup','hold']:
   key=f'{c}{part}-{k}';t=(P/f'reports/{key}.txt').read_text()
   m=re.search(r'Worst case slack is ([-\d.]+)',t);assert m,key
   result[key]=float(m[1]);assert result[key]>0,key
for issue in ['no_clock','generated_clock','loops','latches']:
 assert re.search(r';\s*'+issue+r'\s*;\s*0\s*;',(P/'reports/check-timing.txt').read_text()),issue
assert not re.search(r';\s*DRAM_(?!CLK)',(P/'reports/unconstrained.txt').read_text())
assert not re.search(r'Ignored|could not be matched|Warning \(332',(P/'reports/timing.log').read_text())
assert 'was successful' in (P/'reports/fitting.log').read_text()
assert (P/'quartus/phase9.sdc').read_bytes()==(R/'phase8/quartus/phase8.sdc').read_bytes()
q=(P/'quartus/phase9.qsf').read_text();old=(R/'phase8/quartus/phase8.qsf').read_text()
assert [x for x in q.splitlines() if 'set_location_assignment' in x]==[x for x in old.splitlines() if 'set_location_assignment' in x]
fit=(P/'reports/phase9.fit.rpt').read_text(encoding='latin1')
for label,limit in [('Total logic elements',18752),('M4Ks',52)]:
 m=re.search(label+r'\s*;\s*([\d,]+)\s*/',fit);assert m,label
 assert int(m[1].replace(',',''))<=limit
(P/'reports/timing-summary.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS Phase9: focused tests, integrated regression, genuine engine frames, fit, timing, unchanged pins/constraints, exact RTL/ELF')
