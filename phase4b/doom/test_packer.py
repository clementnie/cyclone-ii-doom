#!/usr/bin/env python3
import pathlib,struct,tempfile,subprocess,json,zlib
script=pathlib.Path(__file__).with_name('pack_image.py')
with tempfile.TemporaryDirectory() as directory:
 p=pathlib.Path(directory)
 def elf(addr):
  ident=b'\x7fELF\x01\x01\x01'+b'\0'*9
  hdr=struct.pack('<16sHHIIIIIHHHHHH',ident,2,243,1,addr,52,0,0,52,32,1,0,0,0)
  ph=struct.pack('<IIIIIIII',1,84,addr,addr,4,8,5,4)
  return hdr+ph+b'\x13\x05\x70\x00'
 (p/'in.elf').write_bytes(elf(0x20020000))
 subprocess.run(['python3',str(script),str(p/'in.elf'),str(p/'out')],check=True)
 m=json.loads((p/'out/manifest.json').read_text());assert m['segments'][0]['crc32']==zlib.crc32(b'\x13\x05\x70\x00')
 for bad in [0x20000000,0x20380000,0x207f0000]:
  (p/'in.elf').write_bytes(elf(bad))
  r=subprocess.run(['python3',str(script),str(p/'in.elf'),str(p/'bad')],capture_output=True)
  assert r.returncode!=0
 print('PASS host packer: valid ELF segment/CRC; framebuffer, WAD and stack overlap rejected')
