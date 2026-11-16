#!/usr/bin/env python3
"""Compile the complete upstream Unix engine object list as freestanding RV32I.
Does not hide unresolved runtime dependencies or claim a bootable executable.
"""
import pathlib,re,subprocess,json
root=pathlib.Path(__file__).resolve().parent
out=root/'build';out.mkdir(exist_ok=True)
source=root/'upstream/doomgeneric'
make=(source/'Makefile').read_text()
names=re.search(r'SRC_DOOM = (.*)',make)[1].split()
names=[n[:-2]+'.c' for n in names if n!='doomgeneric_xlib.o']
flags=['--target=riscv32-unknown-elf','-march=rv32i','-mabi=ilp32','-mno-relax','-msmall-data-limit=0','-Os','-ffreestanding','-fno-builtin','-fdata-sections','-ffunction-sections','-DCMAP256','-DDOOMGENERIC_RESX=320','-DDOOMGENERIC_RESY=200','-I'+str(root/'include'),'-I'+str(source)]
failed=[];objects=[]
with (root/'compile.log').open('w') as log:
 for name in names+['platform.c']:
  src=root/name if name=='platform.c' else source/name
  obj=out/(src.stem+'.o')
  result=subprocess.run(['clang',*flags,'-c',str(src),'-o',str(obj)],stdout=log,stderr=log)
  if result.returncode:failed.append(name)
  else:objects.append(str(obj))
 if not failed:
  result=subprocess.run(['ld.lld','-m','elf32lriscv','-r','-o',str(out/'doom-engine.rv32i.o'),*objects],stdout=log,stderr=log)
  if result.returncode:failed.append('relocatable link')
(root/'compile-status.json').write_text(json.dumps({'compiled':len(objects),'failed':failed,'bootable':False},indent=2)+'\n')
print('Compiled:',len(objects),'Failed:',failed)
raise SystemExit(bool(failed))
