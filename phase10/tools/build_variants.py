#!/usr/bin/env python3
"""Build selectable firmware without changing the default candidate on completion."""
import pathlib,subprocess,os,json,hashlib,shutil
P=pathlib.Path(__file__).resolve().parents[1]
result=[]
for rows,full,opt,label in [(100,0,'-O3','160x100-O3'),(100,0,'-Os','160x100-Os'),(120,0,'-O2','160x120'),(200,0,'-O2','160x200'),(200,1,'-O2','320x200'),(100,0,'-O2','160x100')]:
 subprocess.run(['python3',str(P/'build.py')],env={**os.environ,'DOOM_ROWS':str(rows),'DOOM_FULL':str(full),'DOOM_OPT':opt},check=True)
 elf=P/'artifacts/doom-rv32im.elf';target=P/f'artifacts/doom-{label}-rv32im.elf';shutil.copyfile(elf,target)
 size=subprocess.check_output(['llvm-size',str(elf)],text=True).splitlines()[-1].split()
 result.append(dict(label=label,optimization=opt,lto=True,text=int(size[0]),data=int(size[1]),bss=int(size[2]),sha256=hashlib.sha256(elf.read_bytes()).hexdigest(),hardware_fps=None))
 for n in ['doom.map','size.txt','attributes.txt','compiler-rt-selection.json']:
  shutil.copyfile(P/'reports'/n,P/'reports'/(label+'-'+n))
(P/'reports/compiler-variants.json').write_text(json.dumps(result,indent=2)+'\n')
(P/'artifacts/SHA256SUMS').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.name+'\n' for f in sorted((P/'artifacts').glob('*.elf'))))
