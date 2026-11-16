#!/usr/bin/env python3
import pathlib,json
p=pathlib.Path(__file__).resolve().parents[1]
checks={
 'soc-simulation.log':'PASS CPU -> SDRAM -> palette -> VGA: 3 complete frames',
 'platform-simulation.log':'PASS CPU -> SDRAM -> palette -> VGA: 1 complete frames',
 'scanout-simulation.log':'PASS scanout:',
 'arbiter-simulation.log':'PASS weighted arbiter:',
 'keyboard-simulation.log':'PASS serialized PS/2 -> CPU firmware',
 'regression.log':'PASS Starter Board:',
 'integer-runtime-test.log':'PASS RV32I software integer runtime:',
 'mmio-simulation.log':'PASS framebuffer MMIO:',
 'packer-test.log':'PASS host packer:'}
for name,marker in checks.items():
 text=(p/'reports'/name).read_text()
 assert marker in text and 'FATAL:' not in text and 'Error ' not in text,name
status=json.loads((p/'doom/compile-status.json').read_text())
assert status['compiled']==81 and not status['failed'],status
print('PASS focused framebuffer, CPU/DG video paths, serialized keyboard, arbitration, baseline regression and DOOM object compilation')
