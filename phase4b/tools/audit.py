#!/usr/bin/env python3
import pathlib,hashlib,re,subprocess,csv
root=pathlib.Path(__file__).resolve().parents[2]
for line in (root/'phase4b/baseline.sha256').read_text().splitlines():
 sha,name=line.split();assert hashlib.sha256((root/name).read_bytes()).hexdigest()==sha,name
assert not subprocess.check_output(['git','diff','1757c49','--','phase4','phase2','rtl','sim'],cwd=root),'Baseline modified'
base=(root/'phase4/quartus/phase4.qsf').read_text();new=(root/'phase4b/quartus/phase4b.qsf').read_text()
pattern=r'set_location_assignment (PIN_\w+) -to (\S+)'
assert dict(re.findall(pattern,base))==dict(re.findall(pattern,new)),'Pin map modified'
assert len(dict(re.findall(pattern,new)))==57
assert (root/'phase4/quartus/phase4.sdc').read_bytes()==(root/'phase4b/quartus/phase4b.sdc').read_bytes(),'Timing constraints changed'
print('PASS immutable D1060001/D4000001 images, baseline sources, all 57 pins and exact SDRAM/VGA timing constraints')
