#!/usr/bin/env python3
import pathlib,struct,zlib
FONT=[31599, 11415, 29671, 29647, 23497, 31183, 31215, 29257, 31727, 31695, 31725, 27566, 31015, 27502, 31143, 31140]
def pixel(x,y):
 p=(1 if x<64 else 2 if x<128 else 3 if x<192 else 4 if x<256 else 0) if y<64 else (4 if ((x>>4)^(y>>4))&1 else 0) if y<128 else 3
 if x==y or x==319-y:p=5
 if 144<=x<168 and 144<=y<160:p=6
 if 166<=y<198 and 8<=x<80:
  field,yy=divmod(y-166,11);digit,xx=divmod(x-8,8)
  if yy<10:
   bits=([0x7b24,0x5bed,0x5b6f][field] if digit==0 else FONT[1 if field==1 and digit==8 else 0])
   p=(1 if field==2 else 4) if xx<6 and bits>>(14-(yy//2)*3-xx//2)&1 else 0
 return p
COLORS=[(0,0,0),(255,0,0),(0,255,0),(0,0,255),(255,255,255),(255,255,0),(0,255,255),(255,0,255)]
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
rows=[]
for y in range(480):
 row=bytearray([0])
 for x in range(640):row.extend(COLORS[pixel(x//2,(y-40)//2)] if 40<=y<440 else (0,0,0))
 rows.append(bytes(row))
out=pathlib.Path(__file__).resolve().parents[1]/'reference.png'
out.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',640,480,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b''))
print(out)
