#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH=/tmp/inigo-clang-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/inigo-swift-cache
swift build -c release --disable-sandbox
STAGING="$PWD/.build/package-$(date +%s)"
APP="$STAGING/Inigo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Runtime" "$APP/Contents/Resources/CloudBridge"
python3 scripts/package-localizations.py "$APP/Contents/Resources"
cp Assets/Inigo.icns Assets/Inigo.png Assets/InigoMenu.png "$APP/Contents/Resources/"
cp .build/release/Inigo "$APP/Contents/MacOS/Inigo"
cp .runtime/llama/llama-b12172/llama-server "$APP/Contents/Resources/Runtime/"
cp .runtime/llama/llama-b12172/*.dylib "$APP/Contents/Resources/Runtime/"
cp .runtime/llama/llama-b12172/LICENSE "$APP/Contents/Resources/Runtime/LLAMA-LICENSE"
# Cloud integration remains in source but is not shipped in this local-only release.
mkdir -p "$APP/Contents/Frameworks"
ditto .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"
cp LICENSE "$APP/Contents/Resources/INIGO-LICENSE"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$APP/Contents/Resources/SPARKLE-LICENSE"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.inigo.personal</string>
<key>CFBundleIconFile</key><string>Inigo</string>
<key>CFBundleName</key><string>Inigo</string>
<key>CFBundleDisplayName</key><string>Inigo</string>
<key>CFBundleExecutable</key><string>Inigo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSServices</key><array>
<dict><key>NSMenuItem</key><dict><key>default</key><string>Refine with Inigo</string></dict><key>NSMessage</key><string>refineService</string><key>NSPortName</key><string>Inigo</string><key>NSRequiredContext</key><dict/><key>NSSendTypes</key><array><string>public.utf8-plain-text</string></array></dict>
<dict><key>NSMenuItem</key><dict><key>default</key><string>Translate with Inigo</string></dict><key>NSMessage</key><string>translateService</string><key>NSPortName</key><string>Inigo</string><key>NSRequiredContext</key><dict/><key>NSSendTypes</key><array><string>public.utf8-plain-text</string></array></dict>
</array>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAccessibilityUsageDescription</key><string>Inigo reads and refines the text field you invoke it in. It never records your screen.</string>
</dict></plist>
PLIST
python3 scripts/configure-bundle.py "$APP/Contents/Info.plist"
if [ -n "${INIGO_SIGN_IDENTITY:-}" ]; then
  python3 scripts/sign-bundle.py "$APP" "$INIGO_SIGN_IDENTITY"
else
  codesign --force --deep --sign - "$APP"
fi
if [ "${INIGO_STAGE_ONLY:-0}" = 1 ]; then
  echo "Staged $APP"
  exit 0
fi
mkdir -p "$PWD/dist"
if [ -d "$PWD/dist/Inigo.app" ]; then
  if pgrep -x Inigo >/dev/null; then
    echo "Quit Inigo before installing the new build. The staged app is at $APP" >&2
    exit 1
  fi
  # Archive bytes without moving the registered app into a renamed .app bundle.
  ditto -c -k --keepParent "$PWD/dist/Inigo.app" "$STAGING/Inigo-backup.zip"
  rm -rf "$PWD/dist/Inigo.app"
fi
mv "$APP" "$PWD/dist/Inigo.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$PWD/dist/Inigo.app"
echo "Built $PWD/dist/Inigo.app"
