#!/usr/bin/env python3
"""Run locally: upload credentials via stdin directly to GitHub environment secrets."""
import argparse, base64, getpass, json, pathlib, subprocess, tempfile
REPO = 'vladkampov/Inigo'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--p12', type=pathlib.Path, required=True)
p.add_argument('--api-key', type=pathlib.Path, required=True)
p.add_argument('--key-id', required=True)
p.add_argument('--issuer-id', required=True)
a = p.parse_args()
# Fail before reading/exporting private material if environment is not ready.
r = subprocess.run(['gh','api',f'repos/{REPO}/environments/release'], capture_output=True, text=True)
if r.returncode: raise SystemExit('Configure the release environment first (requires public repo or an eligible GitHub plan).')
e = json.loads(r.stdout)
policy = e.get('deployment_branch_policy') or {}
if not policy.get('custom_branch_policies'): raise SystemExit('Restrict the release environment to main before adding secrets.')
branches = json.loads(subprocess.check_output(['gh','api',f'repos/{REPO}/environments/release/deployment-branch-policies']))
if [(x['name'], x.get('type','branch')) for x in branches['branch_policies']] != [('main','branch')]:
    raise SystemExit('The release environment must allow only the main branch.')
password = getpass.getpass('Password protecting your Developer ID .p12 export: ')
with tempfile.TemporaryDirectory(prefix='inigo-secret-export-') as temp:
    keyfile = pathlib.Path(temp)/'sparkle.key'
    tool = pathlib.Path(__file__).resolve().parent.parent/'.build/artifacts/sparkle/Sparkle/bin/generate_keys'
    subprocess.run([str(tool),'--account','app.inigo.updates','-x',str(keyfile)], check=True)
    values = {
        'DEVELOPER_ID_P12_BASE64': base64.b64encode(a.p12.read_bytes()),
        'DEVELOPER_ID_P12_PASSWORD': password.encode(),
        'APPLE_API_PRIVATE_KEY': a.api_key.read_bytes(),
        'APPLE_API_KEY_ID': a.key_id.encode(),
        'APPLE_API_ISSUER_ID': a.issuer_id.encode(),
        'SPARKLE_PRIVATE_KEY': keyfile.read_bytes(),
    }
    for name, value in values.items():
        subprocess.run(['gh','secret','set',name,'--env','release','--repo',REPO],input=value,check=True)
        print(f'Saved {name}')
print('Secrets saved. Enable RELEASE_SIGNING_ENABLED only after reviewing workflow and protections.')
