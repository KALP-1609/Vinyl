#!/bin/bash
# Builds Vinyl.app (universal: Apple Silicon + Intel), a .zip and a .dmg into ./dist
# Usage: bash scripts/build_app.sh [version]      e.g.  bash scripts/build_app.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Vinyl"
VERSION="${1:-1.0.0}"
OUT="dist"
APP="$OUT/$APP_NAME.app"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "▸ Building universal release binary…"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"

echo "▸ Assembling $APP_NAME.app…"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
printf "APPL????" > "$APP/Contents/PkgInfo"

echo "▸ Generating icon…"
ICONSET="$OUT/AppIcon.iconset"
swift scripts/make_icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "▸ Signing (ad-hoc, no Apple Developer account needed)…"
xattr -cr "$APP"
dot_clean "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "▸ Creating zip…"
ditto -c -k --norsrc --keepParent "$APP" "$OUT/$APP_NAME-$VERSION.zip"

echo "▸ Creating dmg…"
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$OUT/$APP_NAME-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

echo
echo "✓ Done. Files in ./$OUT:"
ls -1 "$OUT"
