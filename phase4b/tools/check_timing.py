#!/usr/bin/env python3
import pathlib,re,json,subprocess
subprocess.run(["python3",str(pathlib.Path(__file__).with_name("build_manifest.py")),"verify"],check=True)

p=pathlib.Path(__file__).resolve().parents[1]
log=(p/'reports/timing.log').read_text()
assert not re.search(r'Ignored|could not be matched',log), 'Incomplete timing constraints; inspect timing.log'
result={}
for corner in ['slow','fast']:
 for kind in ['setup','hold']:
  report=(p/f'reports/{corner}-{kind}.txt').read_text()
  slack=float(re.search(r'Worst case slack is ([-.0-9]+)',report)[1])
  result[f'{corner}_{kind}_ns']=slack
  assert slack>=0,(corner,kind,slack)
for corner in ['slow','fast']:
 for direction in ['in','out']:
  for kind in ['setup','hold']:
   report=(p/f'reports/{corner}-sdram-{direction}-{kind}.txt').read_text()
   match=re.search(r'Worst case slack is ([-.0-9]+)',report)
   assert match, 'No SDRAM interface paths'
   slack=float(match[1]);result[f'{corner}_sdram_{direction}_{kind}_ns']=slack
   assert slack>=0,(corner,direction,kind,slack)
clock=(p/'reports/clocks.txt').read_text()
assert 'sdram_pin' in clock,'Missing external clock'
ucp=(p/'reports/unconstrained.txt').read_text()
# Forwarded DRAM_CLK is itself the clock reference, not a data endpoint.
# Data/control ports must be constrained; report its clock-only UCP explicitly.
assert not re.search(r';\s*DRAM_(?!CLK)',ucp),'Unconstrained SDRAM data/control pin'
print(json.dumps(result,indent=2))
(p/'reports/timing-summary.json').write_text(json.dumps(result,indent=2)+'\n')
