#!/usr/bin/env python3
"""Verify release inputs, third-party pins and tracked publication safety."""
import hashlib,json,pathlib,re,subprocess
R=pathlib.Path(__file__).resolve().parents[1]
manifest=json.loads((R/'releases/v0.1.0/manifest.json').read_text())
for group in ['artifacts','source_sha256']:
 for name,digest in manifest[group].items():
  p=R/name
  assert p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==digest, name
for name in ['phase4b/doom/upstream/SOURCE_SHA256.json','phase5/vendor/compiler-rt/SOURCE_SHA256.json']:
 p=R/name
 for file,digest in json.loads(p.read_text()).items():
  assert hashlib.sha256((p.parent/file).read_bytes()).hexdigest()==digest,file
names=(subprocess.check_output(['git','ls-files'],cwd=R,text=True).splitlines() if (R/'.git').exists() else __import__('json').loads((R/'releases/v0.1.0/files.json').read_text()))
assert names,'No staged/tracked publication files'
secret=re.compile(rb'-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[0-9A-Z]{16}')
for name in names:
 p=R/name;b=p.read_bytes()
 assert p.suffix.lower()!='.wad' and b[:4] not in [b'IWAD',b'PWAD'],name
 assert not any(x in p.relative_to(R).parts for x in ['db','incremental_db','output_files','build','__pycache__']),name
 assert not secret.search(b),'Credential pattern: '+name
# Check new Markdown navigation. Historical third-party/phase docs retain their own layout.
for p in [R/'README.md',R/'NOTICE.md',*list((R/'docs').glob('*.md'))]:
 for dest in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if '://' in dest or dest.startswith('#'):continue
  assert (p.parent/dest.split('#')[0]).exists(),f'{p}: {dest}'
print(f'PASS publication: {len(names)} tracked files, source/artifact hashes, upstream pins, navigation, no WAD/credential patterns')
