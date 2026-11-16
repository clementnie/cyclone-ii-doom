#!/usr/bin/env python3
"""Verify immutable baseline and reference-board pin mapping before Quartus."""
import csv, hashlib, pathlib, re, subprocess
root=pathlib.Path(__file__).resolve().parents[2]
# Phase 2 is immutable, including the four independent byte arrays.
result=subprocess.run(['git','diff','1347b03','--','phase2','rtl','sim'],cwd=root,capture_output=True,text=True,check=True)
assert not result.stdout, 'Baseline modified'
release=root/'phase2/releases/cyclone_ii_diagnostics_D1060001.sof'
assert hashlib.sha256(release.read_bytes()).hexdigest()=='21136060010365b0c0d43e54c0a27d6c6197a965169d0fd2446b4cdc9f32edd4'
qsf=(root/'phase4/quartus/phase4.qsf').read_text()
pins=dict(re.findall(r'set_location_assignment (PIN_\w+) -to (\S+)',qsf))
assert len(pins)==len(re.findall('set_location_assignment',qsf)), 'Pin collision'
for file in ['phase2/quartus_ep2c20/reference/pins.csv','phase4/reference/sdram-pins.csv']:
 for row in csv.DictReader((root/file).open()):
  assert pins.get(row['pin'])==row['signal'], row
assert len(pins)==57, len(pins)
print('PASS: D1060001 SHA256, immutable baseline, 57 unique reference-board pins')
