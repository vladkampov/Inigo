#!/usr/bin/env python3
"""Download only pinned benchmark weights, never change app preferences."""
import pathlib,re,urllib.request,hashlib
def digest_file(file):
 h=hashlib.sha256()
 while chunk:=file.read(4*1024*1024):h.update(chunk)
 return h.hexdigest()
root=pathlib.Path(__file__).resolve().parent.parent
source=(root/'Sources/InigoCore/LocalModels.swift').read_text()
for ident,filename,revision,digest in re.findall(r'\.init\(id:"([^"]+)",name:"[^"]+",filename:"([^"]+)",revision:"([^"]+)",bytes:\d+,sha256:"([^"]+)"',source):
 target=root/'.models'/filename
 target.parent.mkdir(exist_ok=True)
 if not target.exists():
  url=f'https://huggingface.co/unsloth/Qwen3.5-{ident}-GGUF/resolve/{revision}/{filename}'
  temporary=target.with_suffix('.partial')
  print('Downloading',ident,flush=True)
  with urllib.request.urlopen(url,timeout=120) as response,temporary.open('wb') as output:
   while data:=response.read(4*1024*1024):output.write(data)
  temporary.rename(target)
 with target.open('rb') as file:
  actual=digest_file(file)
 if actual!=digest:raise RuntimeError(f'Checksum mismatch: {filename}')
 print('Verified',ident,flush=True)
