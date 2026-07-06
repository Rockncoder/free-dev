#!/usr/bin/env bash
#
# install.sh — build Free Dev (Release) and install it to /Applications.
#
# Run on any Mac that has Xcode. Because the app is built & signed locally,
# Gatekeeper won't complain (no "unidentified developer" prompt).
#
#   ./install.sh            # build + install + launch
#   ./install.sh --login    # also add it as a Login Item (launch at startup)
#
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="FreeDev.app"
DEST="/Applications/$APP_NAME"

echo "▸ Building Free Dev (Release)…"
xcodebuild -project FreeDev.xcodeproj -scheme FreeDev -configuration Release \
  -derivedDataPath .build build >/dev/null

BUILT=".build/Build/Products/Release/$APP_NAME"
[ -d "$BUILT" ] || { echo "✗ Build did not produce $APP_NAME"; exit 1; }

echo "▸ Installing to /Applications…"
# Quit a running copy so we can replace it.
pkill -x FreeDev 2>/dev/null || true
rm -rf "$DEST"
cp -R "$BUILT" "$DEST"
# Strip quarantine in case the folder was transferred over AirDrop/download.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

if [[ "${1:-}" == "--login" ]]; then
  echo "▸ Adding to Login Items…"
  osascript -e "tell application \"System Events\" to make login item at end \
    with properties {path:\"$DEST\", hidden:true}" >/dev/null 2>&1 || \
    echo "  (couldn't add automatically — add it in System Settings → General → Login Items)"
fi

echo "▸ Launching…"
open "$DEST"
echo "✅ Free Dev installed. Look for the bird in your menu bar."
