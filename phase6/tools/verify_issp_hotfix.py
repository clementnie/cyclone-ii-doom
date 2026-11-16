#!/usr/bin/env python3
"""Verify the host-only fix against the preserved, hardware-qualified build.
Does not refresh its source manifest or access hardware.
"""
import hashlib,json,pathlib,re,subprocess
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent
BASELINE='46b63ce'
def original(name):
    return subprocess.check_output(['git','show',f'{BASELINE}:{name}'],cwd=R)
def sha(b):return hashlib.sha256(b).hexdigest()
manifest=json.loads(original('phase6/reports/build-sources.json'))
allowed={'phase6/Makefile','phase6/tools/upload.py','phase6/tools/upload.tcl',
         'phase6/tools/list_jtag.tcl','phase6/tools/test_upload_tcl.tcl'}
changed=[]
for name,expected in manifest.items():
    actual=sha((R/name).read_bytes())
    if actual!=expected:
        assert name in allowed, f'Baseline implementation changed: {name}'
        changed.append(name)
# These proof files and the physical programming image remain byte-for-byte
# identical. A host parser correction does not refresh their qualification.
proofs=['phase6/reports/build-sources.json','phase6/reports/full-boot.json',
        'phase6/reports/phase6.fit.rpt','phase6/reports/check-timing.txt',
        'phase6/reports/unconstrained.txt','phase6/reports/timing.log']
for corner in ['slow','fast']:
    for part in ['','-sdram-in','-sdram-out']:
        for typ in ['setup','hold']:proofs.append(f'phase6/reports/{corner}{part}-{typ}.txt')
sof='phase6/candidates/cyclone_ii_doom_D6000001_20261114T073201Z_d51a123a8b48.sof'
proofs.append(sof)
for name in proofs:assert (R/name).read_bytes()==original(name),f'Baseline proof/image changed: {name}'
assert json.loads((P/'reports/full-boot.json').read_text())['pass']
slacks={}
for name in proofs:
    if re.search(r'/(slow|fast)(-sdram-(in|out))?-(setup|hold)\.txt$',name):
        m=re.search(r'Worst case slack is ([-\d.]+)',(R/name).read_text());assert m,name
        v=float(m[1]);assert v>0,(name,v);slacks[pathlib.Path(name).stem]=v
fit=(P/'reports/phase6.fit.rpt').read_text(errors='replace')
assert 'Warning (171167)' not in fit
assert 'EP2C20F484C7' in fit
for key in ['no_clock','generated_clock','loops','latches']:
    assert re.search(r';\s*'+key+r'\s*;\s*0\s*;', (P/'reports/check-timing.txt').read_text()),key
assert not re.search(r';\s*DRAM_(?!CLK)',(P/'reports/unconstrained.txt').read_text())
logs={
 'discovery-quartus-tests.log':'PASS ISSP discovery: 29 cases',
 'upload-quartus-all-wire-id.log':'Uploaded and verified 92693 packets;',
 'upload-quartus-all-literal-id.log':'Uploaded and verified 92693 packets;',
 'phase6-regression.log':'PASS 10 adversarial loader cases',
 'physical-discovery.log':'index=0 source=480 probe=96 reported_id=OOM6',
}
for name,marker in logs.items():
    t=(P/'reports/hotfix-issp'/name).read_text();assert marker in t,name
    assert not re.search(r'FATAL|FAILED|Traceback|Error [1-9]',t),name
loader=json.loads((P/'reports/loader-boot.json').read_text());assert loader['pass'] and loader['frames']==50
assert 'FRAME 50' in (P/'reports/loader-boot.log').read_text()
report=dict(baseline=BASELINE,changed_baseline_source_paths=sorted(changed),
            unchanged_baseline_sources=len(manifest)-len(changed),sof=sof,sof_sha256=sha((R/sof).read_bytes()),
            timing_slack_ns=slacks,physical_discovery='{0 480 96 OOM6}',
            rtl_firmware_elf_constraints_unchanged=True,physical_upload_performed=False,
            loader_simulation=loader)
(P/'reports/hotfix-issp/verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS host-only hotfix: strict physical discovery; all baseline implementation sources/SOF/timing proofs unchanged; regressions passed')
