#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/configure-bundle.py Xcode/Info.plist
xcodegen generate --spec project.yml
