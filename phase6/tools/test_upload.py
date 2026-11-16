#!/usr/bin/env python3
import pathlib,struct,unittest
from upload import segments,validate_wad,transactions
R=pathlib.Path(__file__).resolve().parents[1]
class UploadTest(unittest.TestCase):
 def setUp(self):self.elf=(R/'artifacts/doom-rv32i.elf').read_bytes();self.wad=(R/'assets/doom1.wad').read_bytes()
 def test_real_iwad(self):self.assertEqual(validate_wad(self.wad)['lumps'],1264)
 def test_bad_lump(self):
  b=bytearray(self.wad);off=struct.unpack_from('<I',b,8)[0];struct.pack_into('<II',b,off,len(b)-1,4)
  with self.assertRaises(ValueError):validate_wad(b)
 def test_oversize(self):
  with self.assertRaisesRegex(ValueError,'exceeds slot'):validate_wad(self.wad+bytes(0x470001-len(self.wad)))
 def test_segment_runtime(self):
  entry,seg=segments(self.elf);self.assertEqual(entry,0x20020000);self.assertEqual(len(seg),2);self.assertGreater(len(seg[1][1]),244000)
 def test_corrupt_elf(self):
  b=bytearray(self.elf);ph=struct.unpack_from('<I',b,28)[0];struct.pack_into('<II',b,ph+8,0x20010000,0x20010000)
  with self.assertRaises(ValueError):segments(b)
 def test_framing(self):
  ps=list(transactions(self.elf,self.wad));self.assertTrue(all(len(p)==60 for p in ps));self.assertEqual(len({p[:4] for p in ps}),len(ps));self.assertEqual(ps[-1][3],5)
if __name__=='__main__':unittest.main()
