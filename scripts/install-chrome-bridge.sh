#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
EXTENSION_ID="${1:-}"
if [[ ! "$EXTENSION_ID" =~ ^[a-p]{32}$ ]]; then echo "Usage: scripts/install-chrome-bridge.sh CHROME_EXTENSION_ID"; exit 1; fi
ROOT="$PWD"
python3 - "$ROOT" "$EXTENSION_ID" <<'PY'
import json,pathlib,sys,shlex
root=pathlib.Path(sys.argv[1]); extension_id=sys.argv[2]
folder=pathlib.Path.home()/'Library/Application Support/Google/Chrome/NativeMessagingHosts'
folder.mkdir(parents=True,exist_ok=True)
launcher=root/'BrowserExtension/native-host.sh'
node=root/'dist/Inigo.app/Contents/Resources/Runtime/node'
launcher.write_text('#!/bin/sh\nexec '+shlex.quote(str(node))+' '+shlex.quote(str(root/'BrowserExtension/native-host.mjs'))+' "$@"\n')
launcher.chmod(0o755)
manifest={'name':'app.inigo.personal','description':'Inigo private native connection','path':str(launcher),'type':'stdio','allowed_origins':['chrome-extension://'+extension_id+'/']}
(folder/'app.inigo.personal.json').write_text(json.dumps(manifest,indent=2))
print('Installed the browser connection for this extension only.')
PY
