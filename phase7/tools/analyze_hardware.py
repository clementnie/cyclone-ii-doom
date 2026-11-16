#!/usr/bin/env python3
"""Compute counter deltas from two manually captured Phase7 JTAG snapshots.
Snapshots must be less than 60 s apart; this utility does not access hardware.
"""
import argparse,pathlib,json,re
p=argparse.ArgumentParser(description=__doc__);p.add_argument('before',type=pathlib.Path);p.add_argument('after',type=pathlib.Path);a=p.parse_args()
def read(path):
 return {n:int(v) for n,v in re.findall(r'^([a-z][a-z0-9_]*) (\d+)$',path.read_text(),re.M)}
x,y=read(a.before),read(a.after);need=['cycles','retired','engine_frames','fetch_requests','fetch_stalls','data_stalls','cache_hits','cache_misses','underflows','mul_entries','div_entries']
assert all(n in x and n in y for n in need),'incomplete counter snapshots'
d={k:(y[k]-x[k])&0xffffffff for k in need}
assert 0<d['cycles']<3000000000,'require snapshots less than 60s apart, same running image without reset'
assert d['retired'] and d['engine_frames'],'interval must contain retired instructions and completed frames'
r=dict(source='user-captured counter logs; acquisition not independently verified',before=str(a.before),after=str(a.after),
 elapsed_seconds=d['cycles']/50e6,frames=d['engine_frames'],fps=50e6*d['engine_frames']/d['cycles'],cpi=d['cycles']/d['retired'],
 fetch_stall_fraction=d['fetch_stalls']/d['cycles'],data_stall_fraction=d['data_stalls']/d['cycles'],
 cache_hit_rate=d['cache_hits']/(d['cache_hits']+d['cache_misses']) if d['cache_hits']+d['cache_misses'] else None,delta=d)
print(json.dumps(r,indent=2))
