#!/usr/bin/env python3
"""Bind the completed functional checks to their RTL/firmware inputs."""
import pathlib,json,hashlib,sys,subprocess
p=pathlib.Path(__file__).resolve().parents[1];root=p.parent
files=list((p/'rtl').glob('*.v'))+list((p/'firmware').glob('*'))
files += [root/'phase4/rtl'/f'{x}.v' for x in ['sdram_controller','rv32i_cpu']]
files += [root/'phase2/rtl'/f'{x}.v' for x in ['onchip_memory','vga_tiles','diagnostic_font']]+list((root/'rtl').glob('*.v'))
files += [p/'doom'/x for x in ['platform.c','platform_test.c','integer_runtime.c','platform_test.ld']]
current={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(files) if f.is_file()}
dest=p/'reports/test-inputs.json'
if sys.argv[1]=='snapshot':
 subprocess.run(['python3',str(p/'tools/verify_tests.py')],check=True)
 dest.write_text(json.dumps(current,indent=2)+'\n')
else:assert json.loads(dest.read_text())==current,'Functional test inputs changed; rerun tests'
print('PASS functional test input manifest')
