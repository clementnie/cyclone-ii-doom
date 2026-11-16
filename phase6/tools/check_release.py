#!/usr/bin/env python3
"""Fail closed on stale builds, RTL regression failures, or timing issues."""
import hashlib,json,pathlib,re,subprocess,sys
P=pathlib.Path(__file__).resolve().parents[1];R=P.parent

def sources():
    files=[*P.glob('rtl/*.v'),*P.glob('firmware/*'),P/'quartus/phase6.qsf',P/'quartus/phase6.sdc']
    files += [*P.glob('*.c'),*P.glob('*.S'),P/'link.ld',P/'runtime/libc.c',P/'artifacts/doom-rv32i.elf']
    # Include all reused RTL and engine sources, plus harnesses defining proof.
    for pattern in ['phase4/rtl/*.v','phase4b/rtl/*.v','phase2/rtl/*.v','rtl/ps2*.v','phase4b/doom/upstream/doomgeneric/*.[ch]','phase5/vendor/compiler-rt/*.[ch]','phase6/sim/*','phase6/tools/*', 'phase6/Makefile', 'phase6/build.py', 'phase6/verify_elf.py', 'phase6/quartus/*.sh', 'phase6/quartus/*.tcl']:
        files.extend(R.glob(pattern))
    return {str(f.relative_to(R)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(set(files)) if f.is_file()}

if len(sys.argv)>1 and sys.argv[1]=='snapshot':
    (P/'reports/build-sources.json').write_text(json.dumps(sources(),indent=2)+'\n');print('Source hashes recorded');sys.exit()
assert sources()==json.loads((P/'reports/build-sources.json').read_text()),'sources changed since verification'
result={}
for corner in ['slow','fast']:
    for part in ['', '-sdram-in','-sdram-out']:
        for typ in ['setup','hold']:
            b=(P/f'reports/{corner}{part}-{typ}.txt').read_text();m=re.search(r'Worst case slack is ([-\d.]+)',b);assert m,(corner,part,typ)
            v=float(m[1]);assert v>=0,(corner,part,typ,v);result[f'{corner}{part}-{typ}_ns']=v
log=(P/'reports/timing.log').read_text();assert not re.search('Ignored|could not be matched|Warning \\(332',log),'timing constraint warning'
checks=(P/'reports/check-timing.txt').read_text()
for key in ['no_clock','multiple_clock','generated_clock','loops','latches']:
    m=re.search(r';\s*'+key+r'\s*;\s*(\d+)',checks);assert m and int(m[1])==0,key
fit=(P/'reports/phase6.fit.rpt').read_text(errors='replace');assert 'Warning (171167)' not in fit, 'ignored fitter assignment'
ucp=(P/'reports/unconstrained.txt').read_text();assert not re.search(r';\s*DRAM_(?!CLK)',ucp),'unconstrained SDRAM port'
assert json.loads((P/'reports/full-boot.json').read_text())['pass'],'full boot not passed'
for name in ['phase4b-regression.log','phase4-regression.log','mailbox-test.log','upload-tests.log','loader-negative-tests.log']:
    b=(P/'reports'/name).read_text();assert not re.search(r'FATAL|FAILED|Traceback|Error [1-9]',b),name
    assert 'PASS' in b or '\nOK\n' in b,name
assert 'PASS functional test input manifest' in (P/'reports/phase4b-regression.log').read_text(), 'Phase4B regression incomplete'
assert "make: Leaving directory" in (P/'reports/phase4-regression.log').read_text(), 'baseline regression incomplete'
for name in ['upload-tcl-test.log','upload-quartus-tcl-test.log','upload-quartus-all-tcl-test.log']:
    assert 'PASS host Tcl:' in (P/'reports'/name).read_text(), name
(P/'reports/timing-summary.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));print('PASS release checks')
