#!/usr/bin/env python3
import pathlib,subprocess
p=pathlib.Path(__file__).resolve().parent;out=p/'build';out.mkdir(exist_ok=True)
flags=['clang','-O1','-g','-ffreestanding','-fno-builtin','-DPHASE5_TEST','-I'+str(p.parent/'phase4b/doom/include')]
subprocess.run(flags+['-c',str(p/'runtime/libc.c'),'-o',str(out/'native-unprefixed.o')],check=True)
names=subprocess.check_output(['llvm-nm','-g','--defined-only',str(out/'native-unprefixed.o')],text=True)
rename=['-D'+line.split()[-1]+'=p5_'+line.split()[-1] for line in names.splitlines() if line.strip()]
subprocess.run(flags+rename+['-fsanitize=address,undefined','-c',str(p/'runtime/libc.c'),'-o',str(out/'native.o')],check=True)
subprocess.run(['clang','-g','-fsanitize=address,undefined',str(p/'runtime/test.c'),str(out/'native.o'),'-o',str(out/'runtime-test')],check=True)
r=subprocess.run([str(out/'runtime-test')],capture_output=True,text=True)
(p/'reports/runtime-test.log').write_text(r.stdout+r.stderr);print(r.stdout+r.stderr);raise SystemExit(r.returncode)
