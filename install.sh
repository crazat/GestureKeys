#!/bin/bash
# GestureKeys build & install script
# Builds to .build, installs to ~/Applications, and launches from there.
# This ensures SMAppService always registers the stable ~/Applications path.

set -euo pipefail

cd "$(dirname "$0")"

INSTALL_DIR="$HOME/Applications"
APP_NAME="GestureKeys.app"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME"
BUILD_PATH=".build/Build/Products/Debug/$APP_NAME"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building..."
xcodebuild -scheme GestureKeys -configuration Debug -derivedDataPath .build build 2>&1 | tail -3

if [ ! -d "$BUILD_PATH" ]; then
    echo "ERROR: Build failed — $BUILD_PATH not found"
    exit 1
fi

echo "==> Stopping running GestureKeys..."
pkill -f "GestureKeys.app/Contents/MacOS/GestureKeys" 2>/dev/null || true
sleep 0.5

echo "==> Installing to $INSTALL_PATH..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_PATH"
cp -R "$BUILD_PATH" "$INSTALL_PATH"

# Remove stale GestureKeys.app copies from DerivedData so macOS Launch Services
# can't accidentally pick an old build when resolving the bundle ID at login.
for dir in "$DERIVED_DATA"/GestureKeys-*/Build/Products/*/; do
    if [ -d "${dir}${APP_NAME}" ]; then
        echo "==> Cleaning stale build: ${dir}${APP_NAME}"
        rm -rf "${dir}${APP_NAME}"
    fi
done

# Also clean the project-local build dir (not .build) if it exists
if [ -d "build/Build/Products/Debug/$APP_NAME" ]; then
    echo "==> Cleaning stale build: build/Build/Products/Debug/$APP_NAME"
    rm -rf "build/Build/Products/Debug/$APP_NAME"
fi

# Register ~/Applications copy as the preferred bundle with Launch Services
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$INSTALL_PATH" 2>/dev/null || true

echo "==> Launching from $INSTALL_PATH..."
open "$INSTALL_PATH"

echo "==> Done. GestureKeys is now running from $INSTALL_PATH"
