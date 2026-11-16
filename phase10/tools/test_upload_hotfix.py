#!/usr/bin/env python3
"""Reproduce the physical block shift and verify the conservative refill fix."""
import importlib.util, pathlib, subprocess, zlib, json, re
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
B=P/'build/hotfix';L=P/'reports/hotfix';B.mkdir(parents=True,exist_ok=True);L.mkdir(exist_ok=True)
s=importlib.util.spec_from_file_location('u',R/'phase6/tools/upload.py');u=importlib.util.module_from_spec(s);s.loader.exec_module(u)
elf=(P/'artifacts/doom-rv32im.elf').read_bytes()
b=u.segments(elf)[1][0][1]
packets=list(u.transactions(elf,(R/'phase6/assets/doom1.wad').read_bytes()))
assert len(packets)==94868 and int.from_bytes(packets[8436][:4],'little')==0x040020f5
raw=b+bytes(32)
shifted=b''.join(raw[i+2:i+32]+raw[i+30:i+32] for i in range(0,len(b),32))[:len(b)]
assert zlib.crc32(b)==0xc5938c86 and zlib.crc32(shifted)==0x873fb4a2
print('PASS exact physical END 040020f5: expected c5938c86, observed shift predicts 873fb4a2')
cases=json.loads((L/'diag-cases.json').read_text())
probes={int(cmd,16)&0xffffff:int(crc,16) for cmd,crc in re.findall(r'END (04[0-9a-f]+).*?probe=E6000007([0-9A-F]{8})', (L/'hardware-diag.log').read_text())}
checked=0
for case in cases:
 n=case['length']
 if n%32:continue
 data=bytes((i*73+19+(i>>3))&255 for i in range(n))
 shifted=b''.join(data[i+2:i+32]+data[i+30:i+32] for i in range(0,n,32))
 assert probes[case['end']]==zlib.crc32(shifted),case
 checked+=1
assert checked==16
print('PASS all 16 fully initialized physical CRC probes match the per-block shift')

# Preserve the original controller directly from the immutable Phase 10 commit.
old=B/'original_controller.v'
old.write_bytes(subprocess.check_output(['git','show','af52b8b:phase10/rtl/phase10_sdram_controller.v'],cwd=R))
for original,early,op in [(True,1,1),(False,0,1),(False,1,1),(False,0,0),(False,1,0)]:
 name=f'block-original{int(original)}-early{early}-open{op}';exe=B/name
 with (L/(name+'.log')).open('w') as log:
  subprocess.run(['/tmp/phase9-tools/usr/bin/iverilog','-B','/tmp/phase9-tools/usr/lib/ivl','-g2012','-s','tb_upload_block',f'-Ptb_upload_block.OBSERVED_EARLY={early}',f'-Ptb_upload_block.OPEN_PAGE={op}','-o',str(exe),str(P/'sim/tb_upload_block.sv'),str(P/'sim/sdram_model.sv'),str(old if original else P/'rtl/phase10_sdram_controller.v')],stdout=log,stderr=log,check=True)
  result=subprocess.run(['/tmp/phase9-tools/usr/bin/vvp',str(exe)],stdout=log,stderr=log)
 text=(L/(name+'.log')).read_text()
 if original:
  assert result.returncode!=0 and 'got=8037eea5 expected=eea55c13' in text,text
  print('PASS original RTL reproduces physical +1-halfword block shift')
 else:
  assert result.returncode==0 and 'PASS' in text,text
  print(text.strip())

for op in [0,1]:
 name=f'random-observed-open{op}';exe=B/name
 with (L/(name+'.log')).open('w') as log:
  subprocess.run(['/tmp/phase9-tools/usr/bin/iverilog','-B','/tmp/phase9-tools/usr/lib/ivl','-g2012','-s','tb_sdram','-Ptb_sdram.OBSERVED_EARLY=1',f'-Ptb_sdram.OPEN_PAGE={op}','-o',str(exe),str(P/'sim/tb_sdram.sv'),str(P/'sim/sdram_model.sv'),str(P/'rtl/phase10_sdram_controller.v')],stdout=log,stderr=log,check=True)
  subprocess.run(['/tmp/phase9-tools/usr/bin/vvp',str(exe)],stdout=log,stderr=log,check=True)
 print((L/(name+'.log')).read_text().strip())
