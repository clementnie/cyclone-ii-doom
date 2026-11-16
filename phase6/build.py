#!/usr/bin/env python3
import pathlib,subprocess,re,json,hashlib
root=pathlib.Path(__file__).resolve().parent;repo=root.parent
out=root/'build';out.mkdir(exist_ok=True)
src=repo/'phase4b/doom/upstream/doomgeneric';vendor=repo/'phase5/vendor/compiler-rt'
flags=['--target=riscv32-unknown-elf','-march=rv32i','-mabi=ilp32','-mno-relax','-msmall-data-limit=0','-Os','-ffreestanding','-fno-builtin','-fdata-sections','-ffunction-sections','-DCMAP256','-DDOOMGENERIC_RESX=320','-DDOOMGENERIC_RESY=200','-I'+str(repo/'phase4b/doom/include'),'-I'+str(src)]
names=[n[:-2]+'.c' for n in re.search(r'SRC_DOOM = (.*)',(src/'Makefile').read_text())[1].split() if n!='doomgeneric_xlib.o']
objects=[];built=[]
with (root/'reports/build.log').open('w') as log:
 def run(cmd):
  r=subprocess.run(cmd,stdout=log,stderr=log);log.flush()
  if r.returncode:raise SystemExit('Build failed; see phase6/reports/build.log')
 def compile_file(path,name=None):
  obj=out/((name or path.stem)+'.o');run(['clang',*flags,'-c',str(path),'-o',str(obj)]);objects.append(str(obj))
 for name in names:compile_file(src/name)
 for name in ['start.S','main.c','platform.c','runtime/libc.c']:compile_file(root/name)
 compile_file(repo/'phase4b/doom/integer_runtime.c')
 mapping={x:'comparedf2' for x in ['ltdf2','ledf2','gtdf2','gedf2','eqdf2','nedf2','unorddf2']}
 mapping.update({'fe_getround':'fp_mode','fe_raise_inexact':'fp_mode'})
 mapping.update({x:'comparesf2' for x in ['ltsf2','lesf2','gtsf2','gesf2','eqsf2','nesf2','unordsf2']})
 for iteration in range(30):
  joined=out/'partial.o';run(['ld.lld','-m','elf32lriscv','-r','-o',str(joined),*objects])
  undefined=subprocess.check_output(['llvm-nm','-u',str(joined)],text=True)
  missing=[line.split()[-1] for line in undefined.splitlines() if line.strip()]
  # Linker script provides these, not a missing library.
  missing=[x for x in missing if x not in ['__heap_start','__heap_end','__data_start','__data_end','__data_load','__bss_start','__bss_end','__stack_top']]
  if not missing:break
  progress=False
  for symbol in missing:
   name=mapping.get(symbol[2:],symbol[2:]) if symbol.startswith('__') else ''
   file=vendor/(name+'.c')
   if name and file.exists() and name not in built:
    compile_file(file,'crt_'+name);built.append(name);progress=True
  if not progress:
   (root/'reports/unresolved.txt').write_text('\n'.join(missing)+'\n');raise SystemExit('Missing implementations: '+', '.join(missing))
 else:raise SystemExit('Runtime dependency closure did not converge')
 elf=root/'artifacts/doom-rv32i.elf'
 run(['ld.lld','-m','elf32lriscv','--gc-sections','--error-limit=0','-T',str(root/'link.ld'),'-Map='+str(root/'reports/doom.map'),'-o',str(elf),*objects])
 (root/'reports/unresolved.txt').write_text(subprocess.check_output(['llvm-nm','-u',str(elf)],text=True))
 (root/'reports/size.txt').write_text(subprocess.check_output(['llvm-size',str(elf)],text=True))
 (root/'reports/attributes.txt').write_text(subprocess.check_output(['llvm-readelf','-h','-A','-l',str(elf)],text=True))
 (root/'reports/compiler-rt-selection.json').write_text(json.dumps(built,indent=2)+'\n')
 (root/'artifacts/SHA256SUMS').write_text(hashlib.sha256(elf.read_bytes()).hexdigest()+'  '+elf.name+'\n')
 print((root/'reports/size.txt').read_text());print('ELF:',elf,'file bytes:',elf.stat().st_size)
