#!/bin/bash
# GestureKeys release build & DMG packaging script.
# Usage: ./scripts/create-release.sh
#
# Prerequisites:
#   - "Developer ID Application" certificate in Keychain
#   - xcrun notarytool configured (xcrun notarytool store-credentials)
#   - create-dmg: brew install create-dmg
#
# Output: release/GestureKeys-{version}.dmg (notarized & stapled)

set -euo pipefail

cd "$(dirname "$0")/.."

# Extract version from project.yml
VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | awk '{print $2}' | tr -d '"')
if [ -z "$VERSION" ]; then
    echo "ERROR: Could not extract MARKETING_VERSION from project.yml"
    exit 1
fi

BUILD_DIR=".build-release"
RELEASE_DIR="release"
APP_NAME="GestureKeys.app"
DMG_NAME="GestureKeys-${VERSION}.dmg"

echo "=== GestureKeys Release Build v${VERSION} ==="
echo ""

# Step 1: Generate project
echo "[1/7] Generating Xcode project..."
xcodegen generate

# Step 2: Build Release
echo "[2/7] Building Release configuration..."
xcodebuild -scheme GestureKeys \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build 2>&1 | tail -5

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Release build failed — $APP_PATH not found"
    exit 1
fi

# Step 3: Verify code signing
echo "[3/7] Verifying code signature..."
codesign -dvvv "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Sealed"
echo ""

# Step 4: Verify Hardened Runtime
echo "[4/7] Checking Hardened Runtime..."
codesign -d --entitlements - "$APP_PATH" 2>&1 | head -20
echo ""

# Step 5: Create DMG
echo "[5/7] Creating DMG..."
mkdir -p "$RELEASE_DIR"
rm -f "$RELEASE_DIR/$DMG_NAME"

if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "GestureKeys" \
        --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 128 \
        --icon "$APP_NAME" 150 190 \
        --app-drop-link 450 190 \
        --hide-extension "$APP_NAME" \
        "$RELEASE_DIR/$DMG_NAME" \
        "$APP_PATH"
else
    echo "  create-dmg not found, using hdiutil fallback..."
    STAGING_DIR=$(mktemp -d)
    cp -R "$APP_PATH" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"
    hdiutil create -volname "GestureKeys" \
        -srcfolder "$STAGING_DIR" \
        -ov -format UDZO \
        "$RELEASE_DIR/$DMG_NAME"
    rm -rf "$STAGING_DIR"
fi

echo "  Created: $RELEASE_DIR/$DMG_NAME"

# Step 6: Notarize (if credentials are available)
echo "[6/7] Notarizing..."
if xcrun notarytool history --keychain-profile "GestureKeys" &>/dev/null 2>&1; then
    xcrun notarytool submit "$RELEASE_DIR/$DMG_NAME" \
        --keychain-profile "GestureKeys" \
        --wait
    echo "[7/7] Stapling notarization ticket..."
    xcrun stapler staple "$RELEASE_DIR/$DMG_NAME"
    echo ""
    echo "=== Release complete: $RELEASE_DIR/$DMG_NAME (notarized) ==="
else
    echo "  Skipping notarization (no 'GestureKeys' keychain profile found)"
    echo "  To set up: xcrun notarytool store-credentials GestureKeys"
    echo ""
    echo "=== Release complete: $RELEASE_DIR/$DMG_NAME (not notarized) ==="
fi

echo ""
echo "DMG size: $(du -h "$RELEASE_DIR/$DMG_NAME" | cut -f1)"
