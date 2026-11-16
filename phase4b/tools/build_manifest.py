#!/usr/bin/env python3
import pathlib,json,hashlib,sys
p=pathlib.Path(__file__).resolve().parents[1];root=p.parent
files=list((p/'rtl').glob('*.v'))+[p/'firmware/boot.hex',p/'quartus/phase4b.qsf',p/'quartus/phase4b.sdc',p/'quartus/hardware_gate.tcl',p/'quartus/timing.tcl']
files += [root/'phase4/rtl'/f'{x}.v' for x in ['sdram_controller','rv32i_cpu']]
files += [root/'phase2/rtl'/f'{x}.v' for x in ['onchip_memory','vga_tiles','diagnostic_font']]+list((root/'rtl').glob('*.v'))
manifest={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(files)}
dest=p/'reports/build-inputs.json'
if sys.argv[1]=='snapshot':dest.write_text(json.dumps(manifest,indent=2)+'\n')
else:assert json.loads(dest.read_text())==manifest,'Build inputs changed; rerun Quartus review'
print('PASS build input manifest' if sys.argv[1]!='snapshot' else 'Saved build input manifest')
