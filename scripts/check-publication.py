#!/usr/bin/env python3
"""Conservative hygiene check, not a replacement for a dedicated secret scan."""
import subprocess,pathlib,re
root=pathlib.Path(__file__).resolve().parent.parent
files=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
errors=[]
for name in filter(None,files):
 path=root/name
 if name.startswith(('.models/','.runtime/','.build/','dist/')) or '/node_modules/' in name:errors.append(name+': generated/binary dependency tracked')
 if path.suffix.lower() in ['.p12','.p8','.pem','.key'] or path.name.startswith('.env'):errors.append(name+': potential secret file')
 if path.is_file() and path.stat().st_size<2_000_000:
  text=path.read_text(errors='ignore')
  if re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',text):errors.append(name+': private key')
  if re.search(r'\bgh[pousr]_[A-Za-z0-9]{30,}\b',text):errors.append(name+': possible GitHub credential')
if errors:raise SystemExit('\n'.join(errors))
print('Tracked-file hygiene check passed. Run GitHub secret scanning before public visibility.')
