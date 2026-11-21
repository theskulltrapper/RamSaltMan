#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "==> Creating RamSaltMan Distribution DMG..."

APP_NAME="RamSaltMan.app"
APP_BUNDLE="build/$APP_NAME"
DIST_DIR="dist"
DMG_ROOT="build/dmg_root"
DMG_OUTPUT="$DIST_DIR/RamSaltMan.dmg"

# 1. Ensure App bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "--> App bundle not found. Building first..."
    ./Scripts/build_app.sh
fi

mkdir -p "$DIST_DIR"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"

# 2. Stage files
echo "--> Staging files..."
cp -R "$APP_BUNDLE" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

# 3. Create DMG
rm -f "$DMG_OUTPUT"
echo "--> Generating compressed DMG: $DMG_OUTPUT..."
hdiutil create \
    -volname "RamSaltMan" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

# 4. Clean staging
rm -rf "$DMG_ROOT"

# 5. Calculate SHA-256 Checksum
echo "--> Calculating SHA-256 Checksum..."
shasum -a 256 "$DMG_OUTPUT" > "$DMG_OUTPUT.sha256"

echo "==> DMG generation complete!"
ls -lh "$DMG_OUTPUT"
cat "$DMG_OUTPUT.sha256"
