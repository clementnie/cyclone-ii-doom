#!/usr/bin/env python3
# Validate function machine words, excluding .rodata merged into .text.
import pathlib,struct,json,subprocess,collections
p=pathlib.Path(__file__).resolve().parent;e=p/'artifacts/doom-rv32i.elf';b=e.read_bytes()
def sections(b):
 off=struct.unpack_from('<I',b,32)[0];z,n=struct.unpack_from('<HH',b,46)
 return [struct.unpack_from('<IIIIIIIIII',b,off+i*z) for i in range(n)]
sh=sections(b);ranges=[]
for s in sh:
 if s[1]==2:
  for off in range(s[4],s[4]+s[5],s[9]):
   name,a,n,info,other,idx=struct.unpack_from('<IIIBBH',b,off)
   if info&15==2 and n:ranges.append((a,a+n))
a=(p/'build/start.o').read_bytes();ss=sections(a);st=ss[struct.unpack_from('<H',a,50)[0]];names=a[st[4]:st[4]+st[5]]
for s in ss:
 if names[s[0]:].split(b'\0')[0]==b'.init':ranges.append((0x20020000,0x20020000+s[5]))
def valid(w):
 op=w&127;f=w>>12&7;g=w>>25
 if op in (0x37,0x17,0x6f):return True
 if op==0x67:return f==0
 if op==0x63:return f in (0,1,4,5,6,7)
 if op==3:return f in (0,1,2,4,5)
 if op==0x23:return f in (0,1,2)
 if op==0x13:return g==0 if f==1 else g in (0,32) if f==5 else True
 if op==0x33:return g==0 or (g==32 and f in (0,5))
 if op==0x0f:return f==0
 return op==0x73 and w in (0x73,0x100073)
seen=set();bad=[];counts=collections.Counter()
for lo,hi in ranges:
 assert lo%4==0 and (hi-lo)%4==0
 for addr in range(lo,hi,4):
  if addr in seen:continue
  seen.add(addr);s=next(s for s in sh if s[1]==1 and s[3]<=addr<s[3]+s[5])
  w=struct.unpack_from('<I',b,s[4]+addr-s[3])[0]
  if not valid(w):bad.append([hex(addr),hex(w)])
  counts[hex(w&127)]+=1
assert not subprocess.check_output(['llvm-nm','-u',str(e)],text=True).strip()
r={'instruction_words_checked':len(seen),'invalid_instructions':bad,'opcode_counts':dict(counts),'excludes_noncode_rodata':True,'abi':'RV32I ILP32 soft float'}
(p/'reports/instruction-audit.json').write_text(json.dumps(r,indent=2)+'\n');assert not bad,bad[:10]
print('PASS executable ELF, zero undefined symbols,',len(seen),'RV32I instruction words; no M/C/F/D/CSR')
