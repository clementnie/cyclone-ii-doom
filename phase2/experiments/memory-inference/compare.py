#!/usr/bin/env python3
"""Compare preserved sources in new scratch directories; never clean project DBs."""
import argparse
import json
import os
from pathlib import Path
import signal
import shutil
import subprocess
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--quartus-bin', type=Path, required=True)
p.add_argument('--output', type=Path, required=True, help='New, nonexistent scratch directory')
p.add_argument('--timeout', type=int, default=600, help='Seconds per Quartus stage')
p.add_argument('--prepare-only', action='store_true')
args = p.parse_args()
here = Path(__file__).resolve().parent
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=False)
qsf = '''set_global_assignment -name FAMILY "Cyclone II"
set_global_assignment -name DEVICE EP2C35F672C6
set_global_assignment -name TOP_LEVEL_ENTITY onchip_memory
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name VERILOG_FILE onchip_memory.v
'''
results = {}
for variant in ('original', 'byte-lanes'):
    run = out / variant
    (run / 'firmware').mkdir(parents=True)
    shutil.copyfile(here / ('onchip_memory.' + variant + '.v'), run / 'onchip_memory.v')
    shutil.copyfile(here / 'boot.hex', run / 'firmware/boot.hex')
    (run / 'memory.qsf').write_text(qsf)
    (run / 'memory.qpf').write_text('QUARTUS_VERSION = "13.0"\nPROJECT_REVISION = "memory"\n')
    if args.prepare_only:
        continue
    results[variant] = {}
    for stage in ('map', 'fit'):
        cmd = [str(args.quartus_bin.resolve() / ('quartus_' + stage)), 'memory',
               '--read_settings_files=on', '--write_settings_files=off']
        start = time.monotonic()
        with (run / (stage + '.log')).open('w') as log:
            proc = subprocess.Popen(cmd, cwd=run, stdout=log, stderr=subprocess.STDOUT,
                                    start_new_session=True)
            try:
                rc = proc.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
                rc = 'timeout'
        results[variant][stage] = {'exit_code': rc, 'wall_seconds': time.monotonic()-start}
        (out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
        print(variant, stage, results[variant][stage], flush=True)
        if rc != 0:
            break
