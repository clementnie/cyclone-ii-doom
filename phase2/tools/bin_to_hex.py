#!/usr/bin/env python3
import pathlib, sys
src, dst = map(pathlib.Path, sys.argv[1:3])
data = src.read_bytes()
if len(data) > 8192:
    raise SystemExit('ROM image exceeds 8192 bytes')
data = data.ljust(8192, b'\0')
dst.write_text(''.join(f'{int.from_bytes(data[n:n+4], "little"):08x}\n' for n in range(0,len(data),4)))
print(f'{src}: {len(src.read_bytes())} load bytes; ROM padded to {len(data)} bytes')
