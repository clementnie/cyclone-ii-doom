#!/usr/bin/env python3
"""Reproduce tested ELF in isolation, preserving its diagnostic __FILE__ paths."""
import pathlib,hashlib,re,runpy,shutil,subprocess,tempfile
R=pathlib.Path(__file__).resolve().parents[1]
reference=(R/'phase9/artifacts/doom-rv32im.elf').read_bytes()
m=re.search(rb'(/[^\x00]+?)/phase4b/doom/upstream/doomgeneric/r_data.c\x00',reference)
assert m,'Reference diagnostic prefix missing'
prefix=m[1].decode()
with tempfile.TemporaryDirectory(prefix='doom-reproduce-') as tmp:
 t=pathlib.Path(tmp)
 names=(subprocess.check_output(['git','ls-files'],cwd=R,text=True).splitlines() if (R/'.git').exists() else __import__('json').loads((R/'releases/v0.1.0/files.json').read_text()))
 for name in names:
  p=pathlib.Path(name)
  if p.parts[0] not in ['phase9','phase4b','phase5'] or any(x in p.parts for x in ['reports','artifacts','candidates','build']):continue
  (t/p).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/p,t/p)
 for name in ['build','reports','artifacts']:(t/'phase9'/name).mkdir(exist_ok=True)
 original_run=subprocess.run
 def mapped_run(cmd,*args,**kwargs):
  if cmd[0]=='clang':cmd=[cmd[0],f'-ffile-prefix-map={t}={prefix}',*cmd[1:]]
  return original_run(cmd,*args,**kwargs)
 subprocess.run=mapped_run
 try:runpy.run_path(str(t/'phase9/build.py'),run_name='__main__')
 finally:subprocess.run=original_run
 built=(t/'phase9/artifacts/doom-rv32im.elf').read_bytes()
 assert built==reference,'ELF differs; retain tested release, inspect tool versions'
 out=R/'phase9/build/reproduced/doom-rv32im.elf';out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(built)
 print('PASS byte-identical tested ELF:',hashlib.sha256(built).hexdigest())
