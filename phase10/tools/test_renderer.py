#!/usr/bin/env python3
import pathlib,subprocess
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
src=R/'phase4b/doom/upstream/doomgeneric'
flags=['-O2','-fwrapv','-fno-strict-aliasing','-ffunction-sections','-fdata-sections','-I'+str(src)]
def run(a):subprocess.run(a,check=True)
base=P/'build/oracle.o'
run(['clang',*flags,'-c',str(src/'r_draw.c'),'-o',str(base)])
names=[l.split()[-1] for l in subprocess.check_output(['llvm-nm','-g','--defined-only',str(base)],text=True).splitlines()]
run(['clang',*flags,*['-D'+n+'=ref_'+n for n in names],'-c',str(src/'r_draw.c'),'-o',str(base)])
run(['clang',*flags,'-DDOOMGENERIC_ROW_SKIP','-DDOOMGENERIC_LOWDETAIL_HALF','-DDOOMGENERIC_FIXEDDIV32',str(P/'sim/test_renderer.c'),str(P/'doom/r_draw.c'),str(P/'doom/m_fixed.c'),str(base),'-Wl,--gc-sections','-o',str(P/'build/test_renderer')])
with (P/'reports/renderer-test.log').open('w') as log:subprocess.run([str(P/'build/test_renderer')],stdout=log,stderr=log,check=True)
print((P/'reports/renderer-test.log').read_text())
