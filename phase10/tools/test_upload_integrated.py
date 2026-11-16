#!/usr/bin/env python3
"""Real ROM/CPU/cache/arbiter/controller upload of the release ELF and IWAD.
Stops at EXEC acknowledgement; no full DOOM simulation or FPGA programming.
"""
import pathlib,subprocess,os
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
B=P/'build/hotfix';L=P/'reports/hotfix';B.mkdir(parents=True,exist_ok=True);L.mkdir(exist_ok=True)
s=(P/'sim/full.cpp').read_text()
s=s.replace('    pi++;sent=false;','''    if((packets[pi][0]>>24)==4){
     if(c.probe[1]!=packets[pi][2])throw std::runtime_error("END CRC value mismatch");
     std::cout<<"VERIFIED END cmd="<<std::hex<<packets[pi][0]<<" crc="<<c.probe[1]<<std::dec<<std::endl;
    }
    pi++;sent=false;
    if(pi==packets.size()){
     if((c.probe[2]!=0xd6000005)||c.underflows)throw std::runtime_error("handoff/underflow");
     std::cout<<"PASS complete ROM upload: "<<pi<<" packets, both ELF CRCs and IWAD CRC, EXEC ACK; cycles="<<cycles<<std::endl;
     return 0;
    }''')
(B/'upload.cpp').write_text(s)
rtl=[str((P/x).resolve()) for x in (P/'Makefile').read_text().split('RTL = ',1)[1].splitlines()[0].split()]
with (L/'integrated-upload-build.log').open('w') as log:
 subprocess.run(['/tmp/phase9-tools/usr/bin/verilator','--cc','--exe','--build','-j','4','-MAKEFLAGS','OPT_FAST=-O3','-Wno-fatal','--top-module','full_top','--Mdir',str(B/'upload-model'),'-CFLAGS','-O3',str(P/'sim/full_top.v'),*rtl,str(B/'upload.cpp')],env={**os.environ,'VERILATOR_ROOT':'/tmp/phase9-tools/usr/share/verilator'},stdout=log,stderr=log,check=True)
subprocess.run(['python3',str(R/'phase6/tools/upload.py'),'--elf',str(P/'artifacts/doom-rv32im.elf'),'--wad',str(R/'phase6/assets/doom1.wad'),'--out',str(B/'upload.hex')],cwd=R,check=True)
with (L/'integrated-upload.log').open('w') as log:
 subprocess.run([str(B/'upload-model/Vfull_top'),str(B/'upload.hex'),'1500000000','3','hotfix-upload'],cwd=R,stdout=log,stderr=log,check=True)
assert 'PASS complete ROM upload' in (L/'integrated-upload.log').read_text()
print((L/'integrated-upload.log').read_text())
