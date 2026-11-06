#!/bin/bash
# Produce a notarized, signed archive and appcast locally. Never publish.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${INIGO_SIGN_IDENTITY:?Set your Developer ID Application identity}"
: "${INIGO_NOTARY_PROFILE:?Set a notarytool Keychain profile}"
: "${INIGO_UPDATE_PUBLIC_KEY:?Set the Sparkle Ed25519 public key}"
VERSION=$(python3 scripts/version.py)
export INIGO_STAGE_ONLY=1 INIGO_PUBLIC_LINKS=1 INIGO_ENABLE_UPDATES=1
bash scripts/test.sh
BUILD_LOG=$(mktemp)
trap 'rm -f "$BUILD_LOG"' EXIT
bash scripts/build.sh | tee "$BUILD_LOG"
APP=$(sed -n 's/^Staged //p' "$BUILD_LOG" | tail -1)
test -d "$APP"
OUT="$PWD/release/artifacts/$VERSION"
mkdir -p "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/notarization.zip"
xcrun notarytool submit "$OUT/notarization.zip" --keychain-profile "$INIGO_NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict "$APP"
spctl --assess --type execute --verbose "$APP"
rm "$OUT/notarization.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/Inigo-$VERSION.zip"
# Uses the Sparkle private key in login Keychain; never writes it into the repo.
.build/artifacts/sparkle/Sparkle/bin/generate_appcast --account app.inigo.updates --download-url-prefix "https://github.com/vladkampov/Inigo/releases/download/v$VERSION/" "$OUT"
shasum -a 256 "$OUT/Inigo-$VERSION.zip" > "$OUT/SHA256SUMS"
echo "Prepared signed release at $OUT. Review and smoke-test before publishing."
