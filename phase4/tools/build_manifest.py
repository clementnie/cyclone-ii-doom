#!/usr/bin/env python3
"""Prevent accepting stale reports after editing any build input."""
import hashlib,json,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[2]
p=root/'phase4'
files=list((p/'rtl').glob('*.v'))+[p/'firmware/boot.hex',p/'quartus/phase4.qsf',p/'quartus/phase4.sdc',p/'quartus/hardware_gate.tcl',p/'quartus/timing.tcl']
files += [root/'phase2/rtl'/f'{n}.v' for n in ['onchip_memory','rv32i_cpu','vga_tiles','diagnostic_font']]
files += list((root/'rtl').glob('*.v'))
manifest={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(files)}
dest=p/'reports/build-inputs.json'
if sys.argv[1]=='snapshot':dest.write_text(json.dumps(manifest,indent=2)+'\n')
else:assert json.loads(dest.read_text())==manifest,'Build inputs changed; rerun Quartus review'
print('PASS build input manifest' if sys.argv[1]!='snapshot' else 'Saved build input manifest')
