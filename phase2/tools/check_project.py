#!/usr/bin/env python3
"""Static consistency check only; does not replace Quartus device/pin legality."""
from pathlib import Path
import re,csv,hashlib,json
q=Path('quartus'); text=(q/'de2_phase2.qsf').read_text()
assert re.search(r'-name DEVICE EP2C35F672C6\s',text)
# Quartus accepts quoted and bare names, including bus indices. Braced
# targets are deliberately rejected: they were a real prior pinout bug.
def targets(pattern):
    return [(a, quoted or bare) for a, quoted, bare in re.findall(
        pattern + r' -to (?:"([^"\n]+)"|([^\s{}"]+))\s*$', text, re.M)]
pairs=targets(r'^set_location_assignment (PIN_\w+)')
assert len(pairs)==40, 'expected 40 valid QSF location targets' 
pins=dict(pairs)
assert len(pins)==40, 'duplicate/missing package pins'
actual={port:pin for pin,port in pins.items()}
reference={row['signal']:row['pin'] for row in csv.DictReader((q/'pins.csv').open())}
assert actual==reference
# Manufacturer table downloaded from Terasic, retained beside the project.
official=dict(re.findall(r'^\s*(\S+)\s+(PIN_\w+)\s+',
    (q/'reference/DE2_Pin_Table.txt').read_text(),re.M))
assert all(official.get(port)==pin for port,pin in reference.items()), 'Terasic pin table mismatch' 
io=[port for _,port in targets(r'^set_instance_assignment -name IO_STANDARD ("3.3-V LVTTL")')]
assert len(io)==40 and set(io)==set(reference)
header=Path('rtl/de2_phase2.v').read_text().split('module de2_phase2(',1)[1].split(');',1)[0]
ports=set(); width=None
for token in header.split(','):
    token=token.strip()
    if token.startswith(('input','output')):
        token=re.sub(r'^(input|output)\s+wire\s*','',token); width=None
        match=re.match(r'\[(\d+):(\d+)\]\s*',token)
        if match: width=tuple(map(int,match.groups())); token=token[match.end():]
    if width is None: ports.add(token)
    else: ports.update(f'{token}[{n}]' for n in range(width[1],width[0]+1))
assert ports==set(reference), (ports-set(reference),set(reference)-ports)
for ref in re.findall(r'-name (?:VERILOG_FILE|SDC_FILE) (\S+)',text): assert (q/ref).is_file(),ref
hexwords=Path('firmware/boot.hex').read_text().splitlines()
assert len(hexwords)==2048 and all(re.fullmatch('[0-9a-f]{8}',s) for s in hexwords)
preserved=Path('build/preserved.json')
if preserved.exists():
    for path,digest in json.loads(preserved.read_text()).items():
        assert hashlib.sha256((Path('..')/path).read_bytes()).hexdigest()==digest,path
    print('PASS preserved input hashes: original Quartus files and PS/2 modules unchanged')
print('PASS project consistency: exact device, 40/40 top-level pins and LVTTL assignments, no duplicates, source/ROM paths')
print('Quartus package legality, fitter pin report and timing have NOT been checked by this script.')
