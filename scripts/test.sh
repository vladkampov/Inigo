#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH=/tmp/inigo-clang-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/inigo-swift-cache
swift test --disable-sandbox
NODE_BIN="${INIGO_NODE:-$(command -v node || true)}"
if [ -z "$NODE_BIN" ]; then NODE_BIN="$HOME/.nvm/versions/node/v24.16.0/bin/node"; fi
"$NODE_BIN" --check CloudBridge/bridge.mjs


"$NODE_BIN" --test CloudBridge/tests/oauth.mjs

python3 scripts/check-localizations.py

python3 -m unittest discover -s scripts/tests
