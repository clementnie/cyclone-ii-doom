#!/usr/bin/env python3
"""Download and validate the intact DOOM 1.9 shareware distribution.
Assets stay ignored by Git. Stdlib only; no DOS installer execution.
"""
import hashlib,io,pathlib,urllib.request,zipfile,json
from upload import validate_wad
ROOT=pathlib.Path(__file__).resolve().parents[1]
URL='https://image.dosgamesarchive.com/games/doom19s.zip'
PACKAGE='cacf0142b31ca1af00796b4a0339e07992ac5f21bc3f81e7532fe1b5e1b486e6'
WAD='1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771'
def main():
    assets=ROOT/'assets';assets.mkdir(exist_ok=True);p=assets/'doom19s.zip'
    if not p.exists():
        with urllib.request.urlopen(URL,timeout=30) as r:p.write_bytes(r.read())
    b=p.read_bytes()
    if hashlib.sha256(b).hexdigest()!=PACKAGE:raise ValueError('shareware package SHA256 mismatch')
    with zipfile.ZipFile(io.BytesIO(b)) as z:joined=z.read('DOOMS_19.1')+z.read('DOOMS_19.2')
    with zipfile.ZipFile(io.BytesIO(joined)) as z:
        wad=z.read('DOOM1.WAD')
        if hashlib.sha256(wad).hexdigest()!=WAD:raise ValueError('IWAD SHA256 mismatch')
        # Preserve all shareware distribution files and licensing locally.
        z.extractall(assets/'distribution')
    r=validate_wad(wad);(assets/'doom1.wad').write_bytes(wad)
    r.update(source=URL,package_sha256=PACKAGE,md5=hashlib.md5(wad).hexdigest())
    (ROOT/'reports/iwad.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
if __name__=='__main__':main()
