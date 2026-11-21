#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "==> Building RamSaltMan..."

BUILD_DIR="build"
APP_NAME="RamSaltMan.app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME"
CACHE_DIR="/tmp/swift-cache"

mkdir -p "$BUILD_DIR"
mkdir -p "$CACHE_DIR"

# 1. Compile C SMC Bridge and Helper
echo "--> Compiling SMC Bridge..."
clang -c -O3 -Wall -Wextra -I Sources/Bridge Sources/Bridge/SMCBridge.c -o "$BUILD_DIR/SMCBridge.o"

echo "--> Compiling Privileged Helper..."
clang -O3 -Wall -Wextra Sources/Helper/RamSaltManHelper.c -framework IOKit -framework CoreFoundation -o "$BUILD_DIR/RamSaltManHelper"

# 2. Collect Swift files
SWIFT_FILES=(
    Sources/Hardware/SMCClient.swift
    Sources/Hardware/MemoryMonitor.swift
    Sources/Hardware/CPUMonitor.swift
    Sources/Hardware/ThermalMonitor.swift
    Sources/App/AppSettings.swift
    Sources/Views/DashboardViewModel.swift
    Sources/App/StatusItemManager.swift
    Sources/Views/MemorySectionView.swift
    Sources/Views/FanControlView.swift
    Sources/Views/SettingsView.swift
    Sources/Views/AboutView.swift
    Sources/Views/MainContainerView.swift
    Sources/App/AppDelegate.swift
    Sources/App/main.swift
)

# 3. Compile Swift binary
echo "--> Compiling Swift sources..."
swiftc -O \
    -module-cache-path "$CACHE_DIR" \
    -import-objc-header Sources/Bridge/SMCBridge.h \
    -framework AppKit \
    -framework SwiftUI \
    -framework IOKit \
    -framework CoreFoundation \
    "$BUILD_DIR/SMCBridge.o" \
    "${SWIFT_FILES[@]}" \
    -o "$BUILD_DIR/RamSaltMan"

# 4. Construct macOS .app Bundle Structure
echo "--> Assembling $APP_NAME bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/RamSaltMan" "$APP_BUNDLE/Contents/MacOS/"
cp "$BUILD_DIR/RamSaltManHelper" "$APP_BUNDLE/Contents/Resources/"
cp Sources/Resources/Info.plist "$APP_BUNDLE/Contents/"
cp Sources/Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"

# 5. Ad-hoc Codesigning with zero network entitlements
echo "--> Signing $APP_NAME..."
codesign --force --deep --sign - --entitlements Sources/Resources/RamSaltMan.entitlements "$APP_BUNDLE"

echo "==> Successfully built $APP_BUNDLE!"
ls -lh "$APP_BUNDLE/Contents/MacOS/RamSaltMan"
