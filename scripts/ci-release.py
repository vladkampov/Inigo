#!/usr/bin/env python3
"""Release runner operations. Never print secrets or publish a release."""
import base64, json, os, pathlib, re, secrets, shutil, subprocess, sys, tempfile
ROOT = pathlib.Path(__file__).resolve().parent.parent
STATE = pathlib.Path(os.environ.get('RUNNER_TEMP', tempfile.gettempdir())) / 'inigo-signing'
def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)
def output(args):
    return subprocess.check_output(args, text=True).strip()
def tag():
    value = os.environ['RELEASE_TAG']
    if not re.fullmatch(r'v\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?', value):
        raise ValueError('Invalid release tag')
    return value
def release():
    pages = json.loads(output(['gh','api','--paginate','--slurp','repos/vladkampov/Inigo/releases?per_page=100']))
    matches = [item for page in pages for item in page if item['tag_name'] == tag()]
    if len(matches) != 1: raise ValueError('Expected exactly one matching release')
    data = matches[0]
    if not data['draft']: raise ValueError('Only draft releases may be built or modified')
    return data
def select():
    data = release()
    # Draft releases can exist before GitHub creates their tag.
    ref = tag() if subprocess.run(['git','rev-parse','--verify',f'refs/tags/{tag()}'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0 else data['target_commitish']
    sha = output(['git','rev-parse',f'{ref}^{{commit}}'])
    run(['git','merge-base','--is-ancestor',sha,'origin/main'])
    run(['git','checkout','--detach',sha])
    if (ROOT/'VERSION').read_text().strip() != tag()[1:]: raise ValueError('Tag and VERSION differ')
    if data['assets']: raise ValueError('Draft already has assets; do not overwrite released builds')
def credentials():
    names = ['DEVELOPER_ID_P12_BASE64','DEVELOPER_ID_P12_PASSWORD','APPLE_API_PRIVATE_KEY','APPLE_API_KEY_ID','APPLE_API_ISSUER_ID','SPARKLE_PRIVATE_KEY']
    if any(not os.environ.get(n) for n in names): raise ValueError('Required release secrets are missing')
    STATE.mkdir(mode=0o700, exist_ok=False)
    os.umask(0o077)
    (STATE/'certificate.p12').write_bytes(base64.b64decode(os.environ[names[0]], validate=True))
    (STATE/'apple.p8').write_text(os.environ['APPLE_API_PRIVATE_KEY'])
    (STATE/'sparkle.key').write_text(os.environ['SPARKLE_PRIVATE_KEY'])
    keychain = str(STATE/'release.keychain-db')
    password = secrets.token_urlsafe(32)
    original = output(['security','list-keychains','-d','user'])
    (STATE/'original-keychains.json').write_text(json.dumps(re.findall(r'"([^"]+)"',original)))
    run(['security','create-keychain','-p',password,keychain])
    run(['security','set-keychain-settings','-lut','7200',keychain])
    run(['security','unlock-keychain','-p',password,keychain])
    run(['security','import',str(STATE/'certificate.p12'),'-k',keychain,'-P',os.environ['DEVELOPER_ID_P12_PASSWORD'],'-T','/usr/bin/codesign'])
    run(['security','set-key-partition-list','-S','apple-tool:,apple:,codesign:','-s','-k',password,keychain], stdout=subprocess.DEVNULL)
    old = json.loads((STATE/'original-keychains.json').read_text())
    run(['security','list-keychains','-d','user','-s',keychain,*old])
    identities = output(['security','find-identity','-v','-p','codesigning',keychain])
    expected = 'Developer ID Application: Vladyslav Kampov (JKAL24VVB9)'
    matches = re.findall(r'([A-Fa-f0-9]{40}) "'+re.escape(expected)+r'"', identities)
    if len(matches) != 1:
        print(identities) # Certificate subjects/fingerprints only; no private material.
        raise ValueError('The exported P12 must contain the expected valid Developer ID Application certificate AND its private key')
    with open(os.environ['GITHUB_ENV'],'a') as f:
        f.write(f'INIGO_SIGN_KEYCHAIN={keychain}\nINIGO_SIGN_HASH={matches[0]}\n')
    run(['xcrun','notarytool','store-credentials','inigo-ci','--key',str(STATE/'apple.p8'),'--key-id',os.environ['APPLE_API_KEY_ID'],'--issuer',os.environ['APPLE_API_ISSUER_ID'],'--keychain',keychain])
    with open(os.environ['GITHUB_ENV'],'a') as f: f.write(f'INIGO_NOTARY_KEYCHAIN={keychain}\n')
def verify():
    import xml.etree.ElementTree as ET
    folder = ROOT/'release/artifacts'/tag()[1:]
    archive = folder/f'Inigo-{tag()[1:]}.zip'
    item = ET.parse(folder/'appcast.xml').find('./channel/item/enclosure')
    signature = item.attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature']
    run([str(ROOT/'.build/artifacts/sparkle/Sparkle/bin/sign_update'),'--ed-key-file',str(STATE/'sparkle.key'),'--verify',str(archive),signature])
    with tempfile.TemporaryDirectory() as temp:
        run(['ditto','-x','-k',str(archive),temp])
        app = str(pathlib.Path(temp)/'Inigo.app')
        run(['codesign','--verify','--deep','--strict',app])
        run(['xcrun','stapler','validate',app])
        run(['spctl','--assess','--type','execute','--verbose',app])
def upload():
    if release()['assets']: raise ValueError('Refusing to overwrite existing assets')
    folder = ROOT/'release/artifacts'/tag()[1:]
    run(['gh','release','upload',tag(),str(folder/f'Inigo-{tag()[1:]}.zip'),str(folder/'SHA256SUMS'),str(folder/'appcast.xml'),'--repo','vladkampov/Inigo'])
def cleanup():
    original = STATE/'original-keychains.json'
    if original.exists(): run(['security','list-keychains','-d','user','-s',*json.loads(original.read_text())])
    keychain = STATE/'release.keychain-db'
    if keychain.exists(): run(['security','delete-keychain',str(keychain)])
    if STATE.exists(): shutil.rmtree(STATE)
if __name__ == '__main__':
    try: {'select':select,'credentials':credentials,'verify':verify,'upload':upload,'cleanup':cleanup}[sys.argv[1]]()
    except subprocess.CalledProcessError:
        # Command arguments may contain credentials; never print the exception.
        print('Release operation failed; inspect the preceding tool error.', file=sys.stderr)
        sys.exit(1)
