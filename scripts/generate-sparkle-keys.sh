#!/bin/bash
# Generate Ed25519 signing keys for Sparkle auto-update.
# Run once, then add the public key to Info.plist (SUPublicEDKey).
# The private key is stored in Keychain automatically by Sparkle.
#
# Usage: ./scripts/generate-sparkle-keys.sh

set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED_DATA=".build"
SPARKLE_BIN="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin"

if [ ! -d "$SPARKLE_BIN" ]; then
    echo "Sparkle tools not found. Building first..."
    xcodegen generate
    xcodebuild -scheme GestureKeys -configuration Debug -derivedDataPath "$DERIVED_DATA" build 2>&1 | tail -3
fi

if [ -f "$SPARKLE_BIN/generate_keys" ]; then
    echo "Generating Ed25519 key pair..."
    "$SPARKLE_BIN/generate_keys"
    echo ""
    echo "=== IMPORTANT ==="
    echo "1. Copy the public key above"
    echo "2. Paste it into Info.plist as the value of SUPublicEDKey"
    echo "3. The private key is stored in your Keychain (Sparkle uses it to sign updates)"
else
    echo "ERROR: generate_keys not found at $SPARKLE_BIN"
    echo "Sparkle may not have been built with the binary tools."
    echo ""
    echo "Alternative: Download Sparkle from https://github.com/sparkle-project/Sparkle/releases"
    echo "and use the bin/generate_keys tool from the release package."
fi
