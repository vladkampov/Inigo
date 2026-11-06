#!/usr/bin/env python3
"""Prepare a beta feed from published releases; verify archive with the pinned public key."""
import base64, hashlib, json, os, pathlib, re, subprocess, tempfile, xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parent.parent
NS='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
REPO='vladkampov/Inigo'
def run(args, **kw): return subprocess.run(args,check=True,**kw)
def output(args): return subprocess.check_output(args,text=True)
def validate_item(data, tag):
    root=ET.fromstring(data);items=root.findall('./channel/item')
    if len(items)!=1: raise ValueError('Expected one release item')
    item=items[0];enclosure=item.find('enclosure')
    name=f'Inigo-{tag[1:]}.zip'
    if enclosure is None or enclosure.get('url')!=f'https://github.com/{REPO}/releases/download/{tag}/{name}': raise ValueError('Unexpected archive URL')
    signature=base64.b64decode(enclosure.get(NS+'edSignature',''),validate=True)
    if len(signature)!=64: raise ValueError('Invalid signature')
    build=item.findtext(NS+'version')
    if not build or not build.isdigit() or int(build)<=0: raise ValueError('Invalid build')
    length=int(enclosure.get('length','0'))
    if not 0<length<256*1024*1024: raise ValueError('Invalid archive size')
    return int(build),name,signature,length

def main():
    pages=json.loads(output(['gh','api','--paginate','--slurp',f'repos/{REPO}/releases?per_page=100']))
    releases=[r for page in pages for r in page if not r['draft'] and r['prerelease'] and re.fullmatch(r'v\d+\.\d+\.\d+-beta\.\d+',r['tag_name'])]
    candidates=[]
    with tempfile.TemporaryDirectory() as temp:
        temp=pathlib.Path(temp)
        for r in releases:
            tag=r['tag_name'];names={a['name'] for a in r['assets']}
            if not {'appcast.xml','SHA256SUMS',f'Inigo-{tag[1:]}.zip'}<=names: continue
            folder=temp/tag;folder.mkdir()
            run(['gh','release','download',tag,'--repo',REPO,'--pattern','appcast.xml','--dir',str(folder)])
            data=(folder/'appcast.xml').read_bytes()
            build,name,signature,length=validate_item(data,tag)
            candidates.append((build,tag,folder,name,signature,length))
        if not candidates: raise ValueError('No published signed beta')
        build,tag,folder,name,signature,length=max(candidates,key=lambda x:x[0])
        if sum(c[0]==build for c in candidates)!=1: raise ValueError('Duplicate beta build numbers')
        for pattern in [name,'SHA256SUMS']:
            run(['gh','release','download',tag,'--repo',REPO,'--pattern',pattern,'--dir',str(folder)])
        archive=folder/name
        digest=hashlib.sha256(archive.read_bytes()).hexdigest()
        if archive.stat().st_size!=length or (folder/'SHA256SUMS').read_text().split()!=[digest,name]: raise ValueError('Archive checksum or size mismatch')
        key=base64.b64decode(json.loads((ROOT/'release/config.json').read_text())['publicEDKey'],validate=True)
        if len(key)!=32: raise ValueError('Invalid pinned key')
        (folder/'public.der').write_bytes(bytes.fromhex('302a300506032b6570032100')+key)
        (folder/'signature').write_bytes(signature)
        run([os.environ.get('INIGO_OPENSSL','openssl'),'pkeyutl','-verify','-pubin','-keyform','DER','-inkey',str(folder/'public.der'),'-rawin','-in',str(archive),'-sigfile',str(folder/'signature')])
        dest=ROOT/'updates/beta';dest.mkdir(parents=True,exist_ok=True)
        (dest/'appcast.xml').write_bytes((folder/'appcast.xml').read_bytes())
        print(f'Prepared published beta {tag}, build {build}; SHA256 and Ed25519 verified.')
if __name__=='__main__':main()
