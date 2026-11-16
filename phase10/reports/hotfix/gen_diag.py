from pathlib import Path
import struct,zlib,json
out=[];cases=[];seq=0
for base in [0x20020000,0x20020020,0x2008b100,0x20380000]:
 for n in [4,8,12,16,28,32,36,52,64,128,512]:
  if base==0x20380000 and n<12:continue
  data=bytes((i*73+19+(i>>3))&255 for i in range(n))
  ps=[(1,0,struct.pack('<I',1)),(2,base,struct.pack('<I',n))]
  ps += [(3,0,data[i:i+52]) for i in range(0,n,52)]
  ps += [(4,0,struct.pack('<I',zlib.crc32(data)))]
  for op,a,b in ps:
   seq+=1;out.append((struct.pack('<II',op<<24|seq,a)+b.ljust(52,b'\0'))[::-1].hex())
  cases.append(dict(end=seq,base=hex(base),length=n,crc=f'{zlib.crc32(data):08X}'))
Path('phase10/build/hotfix/diag.hex').write_text('\n'.join(out)+'\n')
Path('phase10/reports/hotfix/diag-cases.json').write_text(json.dumps(cases,indent=2)+'\n')
