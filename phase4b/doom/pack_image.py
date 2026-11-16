#!/usr/bin/env python3
"""Prepare bounded ELF32/WAD segments for the documented future JTAG loader.
Does not access JTAG or program hardware. No assets are downloaded.
"""
import argparse,pathlib,struct,json,zlib
p=argparse.ArgumentParser();p.add_argument('elf',type=pathlib.Path);p.add_argument('out',type=pathlib.Path);p.add_argument('--wad',type=pathlib.Path);a=p.parse_args()
b=a.elf.read_bytes()
assert b[:7]==b'\x7fELF\x01\x01\x01','ELF32 little endian required'
assert struct.unpack_from('<H',b,18)[0]==243,'RISC-V machine required'
entry,phoff=struct.unpack_from('<II',b,24);phentsize,phnum=struct.unpack_from('<HH',b,42)
assert 0x20020000<=entry<0x20380000,'engine entry outside executable slot'
segments=[];ranges=[];a.out.mkdir(parents=True,exist_ok=True)
for i in range(phnum):
 typ,off,va,pa,filesz,memsz,flags,align=struct.unpack_from('<IIIIIIII',b,phoff+i*phentsize)
 if typ!=1 or memsz==0:continue
 assert 0x20020000<=va and va+memsz<=0x20380000,'segment overlaps reserved memory'
 assert filesz<=memsz and off+filesz<=len(b),'truncated ELF'
 assert all(va+memsz<=lo or va>=hi for lo,hi in ranges),'overlapping ELF segments'
 ranges.append((va,va+memsz));data=b[off:off+filesz];name=f'segment-{i}.bin';(a.out/name).write_bytes(data)
 segments.append({'address':va,'file':name,'length':filesz,'memory_length':memsz,'crc32':zlib.crc32(data)})
assert segments,'No loadable segments'
manifest={'entry':entry,'segments':segments,'transport_implemented':False}
if a.wad:
 data=a.wad.read_bytes();assert data[:4] in [b'IWAD',b'PWAD'],'WAD header required';assert len(data)<=0x470000,'WAD exceeds reserved slot'
 (a.out/'wad.bin').write_bytes(data);manifest['wad']={'address':0x20380000,'length':len(data),'crc32':zlib.crc32(data)}
(a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
