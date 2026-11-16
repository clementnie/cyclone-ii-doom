#!/usr/bin/env python3
"""Validate ELF/IWAD and emit bounded JTAG transactions, or upload via Quartus.
Does not configure the FPGA or write Flash. Python stdlib only.
"""
import argparse, hashlib, json, os, pathlib, struct, subprocess, zlib
BASE=0x20020000
WAD=0x20380000
LIMIT=0x207f0000

def validate_wad(b):
    if len(b)<12 or b[:4]!=b'IWAD': raise ValueError('expected IWAD header')
    count,off=struct.unpack_from('<II',b,4)
    if off>len(b) or count>(len(b)-off)//16: raise ValueError('directory outside IWAD')
    for i in range(count):
        pos,size=struct.unpack_from('<II',b,off+16*i)
        if pos>len(b) or size>len(b)-pos: raise ValueError(f'lump {i} outside IWAD')
    if len(b)>LIMIT-WAD: raise ValueError(f'WAD exceeds slot by {len(b)-(LIMIT-WAD)} bytes; streaming required')
    return dict(size=len(b),lumps=count,sha256=hashlib.sha256(b).hexdigest(),crc32=f'{zlib.crc32(b):08x}')

def segments(b):
    if len(b)<52 or b[:7]!=b'\x7fELF\x01\x01\x01':raise ValueError('expected ELF32 LE')
    typ,machine=struct.unpack_from('<HH',b,16)
    if (typ,machine)!=(2,243):raise ValueError('expected executable RISC-V ELF')
    entry,off=struct.unpack_from('<II',b,24);sz,num=struct.unpack_from('<HH',b,42)
    if sz!=32 or off+sz*num>len(b):raise ValueError('invalid ELF program headers')
    result=[];executable=[]
    for i in range(num):
        kind,start,a,pa,n,m,flags,align=struct.unpack_from('<8I',b,off+i*sz)
        if kind!=1:continue
        if not m:continue
        if a!=pa or a<BASE or a>=WAD or m>WAD-a or n>m or start+n>len(b) or a%4:raise ValueError('ELF segment bounds')
        if any(a<old+len(data) and old<a+m for old,data in result):raise ValueError('ELF segment overlap')
        result.append((a,b[start:start+n]+bytes(m-n)))
        if flags&1:executable.append((a,a+n))
    if not 1<=len(result)<=7 or entry%4 or not any(a<=entry<end for a,end in executable):raise ValueError('invalid entry/count')
    return entry,result

def transactions(elf,wad):
    entry,segs=segments(elf);validate_wad(wad)
    # command, address, 13 little-endian data words. Sequence never repeats.
    seq=0
    def packet(op,a=0,data=b''):
        nonlocal seq
        seq+=1
        return struct.pack('<II',op<<24|seq,a)+data.ljust(52,b'\0')
    yield packet(1,data=struct.pack('<I',len(segs)))
    for a,b in [*segs,(WAD,wad)]:
        yield packet(2,a,struct.pack('<I',len(b)))
        for off in range(0,len(b),52):yield packet(3,data=b[off:off+52])
        yield packet(4,data=struct.pack('<I',zlib.crc32(b)))
    yield packet(5,entry)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--elf',type=pathlib.Path,default=pathlib.Path('phase6/artifacts/doom-rv32i.elf'))
    p.add_argument('--wad',type=pathlib.Path,default=pathlib.Path('phase6/assets/doom1.wad'))
    p.add_argument('--out',type=pathlib.Path,default=pathlib.Path('phase6/build/upload.hex'))
    p.add_argument('--upload',action='store_true');p.add_argument('--cable');p.add_argument('--device');p.add_argument('--index',type=int,default=None,help='optional exact index; default: discover one compatible mailbox')
    p.add_argument('--quartus-stp',default=os.environ.get('QUARTUS_STP', 'quartus_stp'))
    args=p.parse_args();e=args.elf.read_bytes();w=args.wad.read_bytes();entry,segs=segments(e)
    info=dict(entry=hex(entry),segments=[dict(address=hex(a),runtime_bytes=len(b),crc32=f'{zlib.crc32(b):08x}') for a,b in segs],wad=validate_wad(w))
    args.out.parent.mkdir(parents=True,exist_ok=True)
    with args.out.open('w') as f:
        for packet in transactions(e,w):f.write(packet[::-1].hex()+'\n')
    args.out.with_suffix('.json').write_text(json.dumps(info,indent=2)+'\n');print(json.dumps(info,indent=2))
    if args.upload:
        if not args.cable or not args.device:p.error('--upload needs exact --cable and --device names')
        subprocess.run([args.quartus_stp,'-t',str(pathlib.Path(__file__).with_name('upload.tcl')),str(args.out.resolve()),args.cable,args.device,str(args.index) if args.index is not None else 'auto'],check=True,env={**os.environ,'QUARTUS_64BIT':'0'})
if __name__=='__main__':main()
