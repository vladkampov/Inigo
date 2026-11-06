#!/bin/bash
# Produce a notarized, signed archive and appcast locally. Never publish.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${INIGO_SIGN_IDENTITY:?Set your Developer ID Application identity}"
: "${INIGO_NOTARY_PROFILE:?Set a notarytool Keychain profile}"
: "${INIGO_UPDATE_PUBLIC_KEY:?Set the Sparkle Ed25519 public key}"
VERSION=$(python3 scripts/version.py)
export INIGO_STAGE_ONLY=1 INIGO_PUBLIC_LINKS=1
export INIGO_ENABLE_UPDATES="${INIGO_ENABLE_UPDATES:-1}"
bash scripts/test.sh
BUILD_LOG=$(mktemp)
trap 'rm -f "$BUILD_LOG"' EXIT
bash scripts/build.sh | tee "$BUILD_LOG"
APP=$(sed -n 's/^Staged //p' "$BUILD_LOG" | tail -1)
test -d "$APP"
OUT="$PWD/release/artifacts/$VERSION"
mkdir -p "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/notarization.zip"
NOTARY_ARGS=(--keychain-profile "$INIGO_NOTARY_PROFILE")
if [ -n "${INIGO_NOTARY_KEYCHAIN:-}" ]; then NOTARY_ARGS+=(--keychain "$INIGO_NOTARY_KEYCHAIN"); fi
xcrun notarytool submit "$OUT/notarization.zip" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict "$APP"
spctl --assess --type execute --verbose "$APP"
rm "$OUT/notarization.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/Inigo-$VERSION.zip"
# Uses the Sparkle private key in login Keychain; never writes it into the repo.
SPARKLE_ARGS=(--account app.inigo.updates)
if [ -n "${INIGO_SPARKLE_KEY_FILE:-}" ]; then SPARKLE_ARGS=(--ed-key-file "$INIGO_SPARKLE_KEY_FILE"); fi
.build/artifacts/sparkle/Sparkle/bin/generate_appcast "${SPARKLE_ARGS[@]}" --download-url-prefix "https://github.com/vladkampov/Inigo/releases/download/v$VERSION/" "$OUT"
# Explicitly sign even when the app has update checks disabled.
python3 - "$OUT" "$VERSION" "${SPARKLE_ARGS[@]}" <<'PYCODE'
import pathlib, subprocess, sys, xml.etree.ElementTree as ET
folder=pathlib.Path(sys.argv[1]); version=sys.argv[2]; args=sys.argv[3:]
tool='.build/artifacts/sparkle/Sparkle/bin/sign_update'
archive=str(folder/f'Inigo-{version}.zip')
signature=subprocess.check_output([tool,*args,'-p',archive],text=True).strip()
subprocess.run([tool,*args,'--verify',archive,signature],check=True)
ns='http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle',ns)
path=folder/'appcast.xml';tree=ET.parse(path)
item=tree.find('./channel/item/enclosure')
if item is None: raise ValueError('Missing update enclosure')
item.set('{'+ns+'}edSignature',signature)
tree.write(path,encoding='utf-8',xml_declaration=True)
PYCODE
(cd "$OUT" && shasum -a 256 "Inigo-$VERSION.zip" > SHA256SUMS)
echo "Prepared signed release at $OUT. Review and smoke-test before publishing."
