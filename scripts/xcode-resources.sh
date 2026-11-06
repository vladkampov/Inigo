#!/bin/bash
set -euo pipefail
cd "$SRCROOT"
RUNTIME="$SRCROOT/.runtime/llama/llama-b12172"
if [ ! -x "$RUNTIME/llama-server" ]; then
  echo "error: Local runtime missing. Run bash scripts/bootstrap.sh once from the repository."
  exit 1
fi
RESOURCES="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$RESOURCES/Runtime"
python3 scripts/package-localizations.py "$RESOURCES"
cp "$RUNTIME/llama-server" "$RESOURCES/Runtime/"
cp "$RUNTIME/"*.dylib "$RESOURCES/Runtime/"
cp "$RUNTIME/LICENSE" "$RESOURCES/Runtime/LLAMA-LICENSE"
cp LICENSE "$RESOURCES/INIGO-LICENSE"
cp THIRD_PARTY_NOTICES.md "$RESOURCES/"
SPARKLE_LICENSE="$BUILD_DIR/../../SourcePackages/artifacts/sparkle/Sparkle/LICENSE"
if [ -f "$SPARKLE_LICENSE" ]; then cp "$SPARKLE_LICENSE" "$RESOURCES/SPARKLE-LICENSE"; fi
if [ "${CODE_SIGNING_ALLOWED:-NO}" = YES ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  for executable in "$RESOURCES/Runtime/llama-server" "$RESOURCES/Runtime/"*.dylib; do
    codesign --force --options runtime --timestamp --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$executable"
  done
fi
