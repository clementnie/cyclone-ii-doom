#!/usr/bin/env python3
import pathlib,subprocess
P=pathlib.Path(__file__).resolve().parents[1]
s=(P/'runtime/libc.c').read_text();s=s[s.index('void *memcpy('):s.index('void *memmove(')]
(P/'build/memory_functions.c').write_text('#include <stdint.h>\n#include <stddef.h>\n'+s)
subprocess.run(['clang','-O2','-fno-strict-aliasing','-fno-builtin','-Dmemcpy=p9_copy','-Dmemset=p9_fill',str(P/'build/memory_functions.c'),str(P/'sim/test_memory.c'),'-o',str(P/'build/test_memory')],check=True)
with (P/'reports/runtime-test.log').open('w') as log:subprocess.run([str(P/'build/test_memory')],stdout=log,stderr=log,check=True)
print((P/'reports/runtime-test.log').read_text())
