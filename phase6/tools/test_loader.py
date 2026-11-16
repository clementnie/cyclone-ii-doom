#!/usr/bin/env python3
"""Adversarial transactions executed by real ROM firmware on CPU RTL."""
import pathlib,struct,subprocess
R=pathlib.Path(__file__).resolve().parents[2];P=R/'phase6'
def packet(op,a=0,v=0):return struct.pack('<III',op<<24,a,v).ljust(60,b'\0')
reset=packet(1,v=1)
cases={
 'framebuffer':([reset,packet(2,0x20010000,4)],0xe6000003),
 'stack':([reset,packet(2,0x207f0000,4)],0xe6000003),
 'wrap':([reset,packet(2,0xfffffffc,8)],0xe6000003),
 'truncated':([reset,packet(2,0x20020000,8),packet(3,v=0x12345678),packet(2,0x20030000,8)],0xe6000002),
 'crc':([reset,packet(2,0x20020000,4),packet(3,v=0x12345678),packet(4,v=0)],0xe6000007),
 'incomplete':([reset,packet(5,0x20020000)],0xe6000009),
 'end_before_data':([reset,packet(2,0x20020000,4),packet(4)],0xe6000006),
 'overlap':([reset,packet(2,0x20020000,4),packet(3),packet(4,v=0x2144df1c),packet(2,0x20020000,4)],0xe6000004),
 'timeout':([reset,packet(2,0x20020000,56),packet(3)],0xe6000008),
 'reset_recovery':([reset,packet(2,0x20020000,8),packet(1,v=1)],0xd6000001),
}
with (P/'reports/loader-negative-tests.log').open('w') as log:
 for name,(ps,expected) in cases.items():
  path=P/'build'/f'test-{name}.hex'
  with path.open('w') as f:
   for seq,p in enumerate(ps,1):
    b=bytearray(p);b[:4]=struct.pack('<I',struct.unpack_from('<I',b)[0]|seq);f.write(b[::-1].hex()+'\n')
  cmd=[str(P/'build/cpu/Vcpu_top'),str(P/'artifacts/doom-rv32i.elf'),str(P/'assets/doom1.wad'),str(P/'build/symbols.txt'),'5000000','1',str(P/'build/loader.bin'),str(path),f'{expected:x}']
  r=subprocess.run(cmd,cwd=R,capture_output=True,text=True);log.write(name+'\n'+r.stdout+r.stderr);log.flush();assert r.returncode==0,(name,r.stdout,r.stderr)
 print(f'PASS {len(cases)} adversarial loader cases on actual CPU RTL/ROM firmware')
