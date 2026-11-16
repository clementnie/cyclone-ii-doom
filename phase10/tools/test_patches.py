#!/usr/bin/env python3
import pathlib,subprocess
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent;src=R/'phase4b/doom/upstream/doomgeneric'
flags=['-O2','-ffunction-sections','-fdata-sections','-I'+str(src)]
def run(a):subprocess.run(a,check=True)
b=P/'build/patch_oracle.o';run(['clang',*flags,'-c',str(src/'v_video.c'),'-o',str(b)])
names=[l.split()[-1] for l in subprocess.check_output(['llvm-nm','-g','--defined-only',str(b)],text=True).splitlines()]
run(['clang',*flags,*['-D'+n+'=ref_'+n for n in names],'-c',str(src/'v_video.c'),'-o',str(b)])
run(['clang',*flags,'-DDOOMGENERIC_ROW_SKIP',str(P/'sim/test_patches.c'),str(P/'doom/v_video.c'),str(b),str(src/'m_bbox.c'),'-Wl,--gc-sections','-o',str(P/'build/test_patches')])
with (P/'reports/patches-test.log').open('w') as log:subprocess.run([str(P/'build/test_patches')],stdout=log,stderr=log,check=True)
print((P/'reports/patches-test.log').read_text())
