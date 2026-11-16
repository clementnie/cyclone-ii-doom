#!/usr/bin/env python3
"""Fail closed: exact Phase 10 source/ELF hashes, simulation, fit and timing."""
import pathlib, json, hashlib, re, sys
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
files=[*P.glob('rtl/*.v'),*P.glob('sim/*'),*P.glob('quartus/*.qsf'),*P.glob('quartus/*.sdc'),P/'artifacts/doom-rv32im.elf',R/'phase6/firmware/boot.hex']
files += list((P/'doom').glob('*'))+list((R/'phase4b/doom/upstream/doomgeneric').glob('*.c'))+list((R/'phase4b/doom/upstream/doomgeneric').glob('*.h'))
files += [*P.glob('*.c'),*P.glob('*.S'),*P.glob('*.ld'),*P.glob('runtime/*.c'),*P.glob('firmware/*'),P/'build.py']
files+=list(P.glob('tools/test_upload*.py'))
files+=list((R/'phase4b/rtl').glob('*.v'))+list((R/'phase2/rtl').glob('*.v'))+list((R/'rtl').glob('ps2*.v'))
current={str(f.relative_to(R)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(files) if f.is_file()}
if sys.argv[1:] == ['snapshot']:
 (P/'reports/build-sources.json').write_text(json.dumps(current,indent=2)+'\n');sys.exit()
assert current==json.loads((P/'reports/build-sources.json').read_text()),'source/ELF changed'
for name in ['runtime-test','tb_cpu','tb_traps','tb_m','tb_cache','tb_sdram','tb_framebuffer_soc','tb_keyboard-fast','tb_mmio','renderer-test','patches-test','video-modes']:
 t=(P/f'reports/{name}.log').read_text();assert 'PASS' in t and 'FATAL' not in t,name
r=json.loads((P/'reports/phase10-boot.json').read_text());assert r['pass'] and r['game_renders']>=3 and r['vga_frames_captured']>=2 and r['underflows']==0
scope=json.loads((P/'reports/boot-scope.json').read_text())
assert hashlib.sha256((P/'artifacts/doom-rv32im.elf').read_bytes()).hexdigest()==scope['elf_sha256'],'boot ELF differs from default candidate'
result={}
for c in ['slow','fast']:
 for part in ['','-sdram-in','-sdram-out']:
  for k in ['setup','hold']:
   key=f'{c}{part}-{k}';t=(P/f'reports/{key}.txt').read_text()
   m=re.search(r'Worst case slack is ([-\d.]+)',t);assert m,key
   result[key]=float(m[1]);assert result[key]>0,key
for c in ['slow','fast']:
 for kind in ['recovery','removal']:
  t=(P/f'reports/{c}-{kind}.txt').read_text();m=re.search(r'Worst case slack is ([-\d.]+)',t);assert m and float(m[1])>0,(c,kind)
for issue in ['no_clock','generated_clock','loops','latches']:
 assert re.search(r';\s*'+issue+r'\s*;\s*0\s*;',(P/'reports/check-timing.txt').read_text()),issue
assert not re.search(r';\s*DRAM_(?!CLK)',(P/'reports/unconstrained.txt').read_text())
assert not re.search(r'Ignored|could not be matched|Warning \(332',(P/'reports/timing.log').read_text())
assert 'was successful' in (P/'reports/fitting.log').read_text()
assert (P/'quartus/phase10.sdc').read_bytes()==(R/'phase8/quartus/phase8.sdc').read_bytes()
q=(P/'quartus/phase10.qsf').read_text();old=(R/'phase8/quartus/phase8.qsf').read_text()
assert [x for x in q.splitlines() if 'set_location_assignment' in x]==[x for x in old.splitlines() if 'set_location_assignment' in x]
fit=(P/'reports/phase10.fit.rpt').read_text(encoding='latin1')
for label,limit in [('Total logic elements',18752),('M4Ks',52)]:
 m=re.search(label+r'\s*;\s*([\d,]+)\s*/',fit);assert m,label
 assert int(m[1].replace(',',''))<=limit
for name,digest in json.loads((P/'reports/preserved-phase9.json').read_text()).items():
 assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,'Phase 9 release changed'
for name in ['block-tests','integrated-upload','integrated-pixels']:
 t=(P/f'reports/hotfix/{name}.log').read_text();assert 'PASS' in t and 'FATAL' not in t,name
upload=(P/'reports/hotfix/integrated-upload.log').read_text()
for crc in ['c5938c86','10c448be','162b696a']:assert 'crc='+crc in upload,crc
assert 'PASS complete ROM upload: 94868 packets' in upload
for name,digest in json.loads((P/'reports/hotfix/preserved-releases.json').read_text()).items():
 assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,'preserved release changed: '+name
(P/'reports/timing-summary.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS Phase10 hotfix: focused reproduction/regression, complete ROM ELF/IWAD upload, integrated pixels, fit/timing, unchanged pins/constraints, preserved releases, source/ELF snapshot; DOOM boot is historical')
