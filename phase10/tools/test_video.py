#!/usr/bin/env python3
import pathlib,subprocess,os
P=pathlib.Path(__file__).resolve().parents[1]
with (P/'reports/video-modes-build.log').open('w') as log:
 subprocess.run(['/tmp/phase9-tools/usr/bin/verilator','--binary','--timing','--build','-j','4','-Wno-fatal','--top-module','tb_video_modes','--Mdir',str(P/'build/videomodes'),str(P/'sim/tb_video_modes.sv'),str(P/'rtl/framebuffer.v')],env={**os.environ,'VERILATOR_ROOT':'/tmp/phase9-tools/usr/share/verilator'},stdout=log,stderr=log,check=True)
with (P/'reports/video-modes.log').open('w') as log:subprocess.run([str(P/'build/videomodes/Vtb_video_modes')],stdout=log,stderr=log,check=True)
print((P/'reports/video-modes.log').read_text())
