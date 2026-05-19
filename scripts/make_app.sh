#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CryptoMinbar"
APP_DIR="$ROOT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
DMG_PATH="$ROOT_DIR/$APP_NAME.dmg"

echo "==> Building release binary..."
swift build --package-path "$ROOT_DIR" -c release

echo "==> Assembling .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CryptoMinbar</string>
    <key>CFBundleIdentifier</key>
    <string>local.crypto-minbar</string>
    <key>CFBundleName</key>
    <string>CryptoMinbar</string>
    <key>CFBundleDisplayName</key>
    <string>Crypto Minibar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Crypto Minibar</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
</dict>
</plist>
PLIST

echo "==> Built $APP_DIR"

echo "==> Signing .app bundle..."
codesign --force --deep --sign - --identifier "local.crypto-minbar" "$APP_DIR"

echo "==> Creating DMG..."
STAGING_DIR=$(mktemp -d)
cp -r "$APP_DIR" "$STAGING_DIR/"
ln -sf /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "==> Created $DMG_PATH"
echo ""
echo "Done! To install: open $DMG_PATH and drag to Applications."
