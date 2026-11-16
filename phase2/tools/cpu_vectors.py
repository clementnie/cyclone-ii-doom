#!/usr/bin/env python3
"""Deterministic independent RV32I reference trace, including random operands."""
from pathlib import Path
import random
r=random.Random(0xDE232)
words=[]
def I(op,rd,f,a,imm): return ((imm&4095)<<20)|(a<<15)|(f<<12)|(rd<<7)|op
def R(rd,f,a,b,hi=0): return hi<<25|b<<20|a<<15|f<<12|rd<<7|0x33
def S(f,a,b,off): return ((off&0xfe0)<<20)|b<<20|a<<15|f<<12|((off&31)<<7)|0x23
def B(f,a,b,off): return ((off>>12&1)<<31)|((off>>5&63)<<25)|b<<20|a<<15|f<<12|((off>>1&15)<<8)|((off>>11&1)<<7)|0x63
def J(rd,off): return ((off>>20&1)<<31)|((off>>1&1023)<<21)|((off>>11&1)<<20)|((off>>12&255)<<12)|rd<<7|0x6f
words += [0x00004437] # x8 data base 0x4000
for n in range(1,8):
    words += [(r.getrandbits(20)<<12)|(n<<7)|0x37,I(0x13,n,0,n,r.randrange(-2048,2048))]
words += [I(0x13,1,0,0,-1),I(0x13,2,0,0,1),I(0x13,3,0,0,31),I(0x13,4,1,2,31)]
# Every register ALU variant and rd=x0.
for f,h in [(0,0),(0,32),(1,0),(2,0),(3,0),(4,0),(5,0),(5,32),(6,0),(7,0)]:
    for a,b in [(1,2),(4,3),(2,1),(0,0)]: words += [R(5,f,a,b,h),R(0,f,a,b,h)]
for f in [0,2,3,4,6,7]:
    for imm in [-2048,-1,0,2047]: words += [I(0x13,6,f,1,imm)]
for f,hi in [(1,0),(5,0),(5,1024)]:
    for sh in [0,1,31]: words += [I(0x13,7,f,4,hi|sh)]
# All byte lanes, both halfwords, signed/unsigned loads and load to x0.
words += [S(2,8,1,0)]
for lane in range(4):
    words += [S(0,8,4,lane),I(0x03,9,0,8,lane),I(0x03,10,4,8,lane)]
words += [I(0x13,11,0,0,-128)]
for lane in range(4): words += [S(0,8,11,lane),I(0x03,9,0,8,lane),I(0x03,10,4,8,lane)]
for lane in [0,2]: words += [S(1,8,1,lane),I(0x03,9,1,8,lane),I(0x03,10,5,8,lane)]
words += [I(0x03,0,2,8,0),I(0x03,12,2,8,0),I(0x13,13,0,8,4),I(0x03,14,2,13,-4)]
# Taken and untaken comparisons with skipped sentinel writes.
for f in [0,1,4,5,6,7]:
    for a,b in [(1,2),(2,1),(1,1)]:
        words += [B(f,a,b,8),I(0x13,15,0,15,1)]
words += [I(0x13,16,0,0,3),I(0x13,16,0,16,-1),B(1,16,0,-4)]
words += [J(17,8),I(0x13,18,0,18,999)]
# AUIPC/JALR; odd target bit0 is cleared; rd == rs1 must use old value.
pc=len(words)*4
words += [0x00000997,I(0x13,19,0,19,13),I(0x67,19,0,19,0)]
words += [0x0ff0000f] # FENCE
for _ in range(300):
    a,b=r.randrange(32),r.randrange(32)
    rd=r.choice([0,1,2,3,4,5,6,7,9,10,11,12,14,15,17,18,20,21,22,23,24,25,26,27,28,29,30,31])
    f=r.randrange(8)
    if r.randrange(2): words.append(R(rd,f,a,b,r.choice([0,32]) if f in [0,5] else 0))
    else:
        imm=r.randrange(-2048,2048) if f not in [1,5] else r.randrange(32)|(1024 if f==5 and r.randrange(2) else 0)
        words.append(I(0x13,rd,f,a,imm))
words += [0x00100073]
# Interpreter uses byte-addressed memory and sequential architectural updates.
mem=bytearray(65536)
for n,w in enumerate(words): mem[n*4:n*4+4]=w.to_bytes(4,'little')
def sx(x,b): return x-(1<<b) if x&(1<<(b-1)) else x
def signed(x): return sx(x,32)
regs=[0]*32; pc=0; trace=[]; visited=set()
for _ in range(3000):
    w=int.from_bytes(mem[pc:pc+4],'little'); op=w&127; rd=w>>7&31; f=w>>12&7; a=regs[w>>15&31]; b=regs[w>>20&31]; hi=w>>25
    nxt=pc+4; value=None; imm=sx(w>>20,12)
    if w==0x00100073: break
    visited.add((op,f,hi if op==0x33 else 0))
    if op==0x37: value=w&0xfffff000
    elif op==0x17: value=pc+(w&0xfffff000)
    elif op in [0x13,0x33]:
        rhs=imm&0xffffffff if op==0x13 else b
        sh=rhs&31
        if f==0: value=a-rhs if op==0x33 and hi==32 else a+rhs
        elif f==1: value=a<<sh
        elif f==2: value=int(signed(a)<signed(rhs))
        elif f==3: value=int(a<rhs)
        elif f==4: value=a^rhs
        elif f==5: value=signed(a)>>sh if hi==32 else a>>sh
        elif f==6: value=a|rhs
        else: value=a&rhs
    elif op==0x03:
        ea=(a+imm)&0xffffffff; width={0:1,1:2,2:4,4:1,5:2}[f]
        value=int.from_bytes(mem[ea:ea+width],'little')
        if f<2: value=sx(value,width*8)
    elif op==0x23:
        off=sx((w>>25)<<5|(w>>7&31),12); ea=(a+off)&0xffffffff; width=1<<f
        mem[ea:ea+width]=(b&((1<<(width*8))-1)).to_bytes(width,'little')
    elif op==0x63:
        off=sx((w>>31)<<12|((w>>7)&1)<<11|((w>>25)&63)<<5|((w>>8)&15)<<1,13)
        take={0:a==b,1:a!=b,4:signed(a)<signed(b),5:signed(a)>=signed(b),6:a<b,7:a>=b}[f]
        if take: nxt=pc+off
    elif op==0x6f:
        off=sx((w>>31)<<20|((w>>12)&255)<<12|((w>>20)&1)<<11|((w>>21)&1023)<<1,21)
        value=pc+4; nxt=pc+off
    elif op==0x67: value=pc+4; nxt=(a+imm)&0xfffffffe
    elif op==0x0f: pass
    else: raise RuntimeError(hex(w))
    if value is not None and rd: regs[rd]=value&0xffffffff
    pc=nxt&0xffffffff; assert not(pc&3)
    trace.extend([pc]+regs)
else: raise RuntimeError('reference did not halt')
p=Path('build'); p.mkdir(exist_ok=True)
(p/'cpu_program.hex').write_text(''.join(f'{w:08x}\n' for w in words))
(p/'cpu_trace.hex').write_text(''.join(f'{w:08x}\n' for w in trace))
(p/'cpu_meta.vh').write_text(f'`define TRACE_STEPS {len(trace)//33}\n`define PROGRAM_WORDS {len(words)}\n`define STOP_PC 32\'h{pc:08x}\n')
print(f'CPU vectors: {len(words)} words; {len(trace)//33} architectural retirement comparisons')
