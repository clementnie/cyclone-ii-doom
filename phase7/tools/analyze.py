#!/usr/bin/env python3
import pathlib,re,json
P=pathlib.Path(__file__).resolve().parents[1]
r={}
for variant in ['baseline','cached']:
 log=(P/f'reports/{variant}-boot.log').read_text();frames=[];pending=None
 for line in log.splitlines():
  m=re.match(r'GAMEFRAME (\d+) cycles=(\d+)',line)
  if m:pending=(int(m[1]),int(m[2]))
  elif line.startswith('PERF ') and pending:frames.append((*pending,list(map(int,line.split()[1:]))));pending=None
 samples=[]
 for before,after in zip(frames,frames[1:]):
  n,cy,p=after;delta=[(b-a)&0xffffffff for a,b in zip(before[2],p)];cycles=cy-before[1];ins=delta[1];fetches=delta[2];data=delta[24]
  samples.append(dict(frame=n,cycles=cycles,seconds_at_50mhz=cycles/50e6,fps_model=50e6/cycles,
   retired=ins,cpi=cycles/ins if ins else None,fetch_stall_fraction=delta[3]/cycles,
   data_stall_fraction=delta[4]/cycles,mean_fetch_wait=delta[12]/fetches if fetches else None,
   mean_data_wait=delta[14]/data if data else None,cache_hit_rate=delta[16]/(delta[16]+delta[17]) if delta[16]+delta[17] else None,
   mul_entries=delta[22],udiv32_entries=delta[23],sdram_reads=delta[5],sdram_writes=delta[6],framebuffer_writes=delta[8],underflows=p[9]))
 r[variant]=dict(frames=len(frames),samples=samples,simulation_only=True)
(P/'reports/comparison.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
