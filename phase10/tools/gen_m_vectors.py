#!/usr/bin/env python3
from pathlib import Path
import random
rng=random.Random(9)
pairs=[(0,0),(1,0),(0xffffffff,0),(0x80000000,0xffffffff),(0x80000000,1),(0x7fffffff,0x80000000),(0xffffffff,0xffffffff),(0x80000000,0x80000000)]
pairs += [(rng.getrandbits(32),rng.getrandbits(32)) for _ in range(120)]
def signed(x):return x-(1<<32) if x>>31 else x
out=[]
for a,b in pairs:
 for f in range(8):
  aa,bb=(signed(a),signed(b)) if f in (4,6) else (a,b)
  q=0xffffffff if bb==0 else abs(aa)//abs(bb)*(-1 if (aa<0)!=(bb<0) else 1)
  rem=aa if bb==0 else aa-q*bb
  x=[a*b,(signed(a)*signed(b))>>32,(signed(a)*b)>>32,(a*b)>>32,q,q,rem,rem][f]
  out.extend([a,b,f,x&0xffffffff])
(Path(__file__).resolve().parents[1]/'build/m_vectors.hex').write_text('\n'.join(f'{x:08x}' for x in out)+'\n')
