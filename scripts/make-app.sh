#!/bin/bash
# Assembles build/Argus.app from the SwiftPM build (ADR-006, milestone M1a).
# Screen Recording TCC grants are keyed to the app bundle, not the bare SPM
# executable, so capture acceptance always runs through this bundle.
#
# Signing: the default ad-hoc identity ("--sign -") keeps the bundle
# launchable locally, but every rebuild produces a new CDHash, which macOS
# may treat as a new app and ask for the Screen Recording grant again. For a
# stable identity across rebuilds, create a self-signed Code Signing
# certificate in Keychain Access once and run:
#   ARGUS_SIGN_IDENTITY="Argus Dev" scripts/make-app.sh
#
# Usage: scripts/make-app.sh            # release build
#        DEBUG=1 scripts/make-app.sh    # debug build (faster compile)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

config="release"
if [ "${DEBUG:-0}" = "1" ]; then
  config="debug"
fi

version="${ARGUS_VERSION:-0.1.0}"
bundle_id="${ARGUS_BUNDLE_ID:-com.bayernjf.argus}"
sign_identity="${ARGUS_SIGN_IDENTITY:--}"
app="build/Argus.app"

echo "[make-app] swift build -c $config"
swift build -c "$config" --product Argus

binary=".build/$config/Argus"
if [ ! -f "$binary" ]; then
  echo "[make-app] expected binary missing: $binary" >&2
  exit 1
fi

echo "[make-app] assembling $app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Argus"

# PkgInfo: standard APPL signature with an unknown creator code.
printf 'APPL????' > "$app/Contents/Resources/PkgInfo"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Argus</string>
    <key>CFBundleExecutable</key>
    <string>Argus</string>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Argus</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${version}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Argus 只在你明确选择监控的窗口内读取画面，用于本地检测 AI 回复状态。画面仅保存在内存，不落盘、不上传。</string>
</dict>
</plist>
PLIST

echo "[make-app] codesign (identity: ${sign_identity})"
codesign --force --sign "${sign_identity}" "$app"

codesign --verify --strict "$app"
echo "[make-app] done: $app ($(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist"))"
