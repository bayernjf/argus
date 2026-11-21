#!/usr/bin/env bash
# Builds the synthetic M3 acceptance fixtures and the read-only phase sampler.
# Everything is written under build/fixtures; nothing is installed or networked.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build/fixtures"
APPS="$OUT/Apps"
ARCH="$(uname -m)"

mkdir -p "$APPS"

xcrun swiftc "$ROOT/Fixtures/ArgusChatProbe.swift" \
  -target "$ARCH-apple-macos14.0" \
  -framework AppKit \
  -o "$OUT/ArgusChatProbe"
xcrun swiftc "$ROOT/Fixtures/PhaseSampler.swift" \
  -target "$ARCH-apple-macos14.0" \
  -framework AppKit \
  -framework ApplicationServices \
  -o "$OUT/PhaseSampler"

for suffix in A B C D; do
  app="$APPS/ArgusFixture$suffix.app"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS"
  cp "$OUT/ArgusChatProbe" "$app/Contents/MacOS/ArgusChatProbe"
  lower="$(printf '%s' "$suffix" | tr '[:upper:]' '[:lower:]')"
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>ArgusChatProbe</string>
  <key>CFBundleIdentifier</key><string>com.bayernjf.argus-fixture-$lower</string>
  <key>CFBundleName</key><string>Argus Fixture $suffix</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
  codesign --force --sign - --timestamp=none "$app" >/dev/null
done

echo "fixtures: $APPS"
echo "probe:    $OUT/ArgusChatProbe"
echo "sampler:  $OUT/PhaseSampler"
