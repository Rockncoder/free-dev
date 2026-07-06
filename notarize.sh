#!/usr/bin/env bash
#
# notarize.sh — build a signed, notarized, stapled FreeDev.dmg for direct
# (non-App-Store) distribution.
#
# ── One-time setup (needs a paid Apple Developer account) ────────────────────
#   1. Install a "Developer ID Application" certificate:
#        Xcode → Settings → Accounts → (your Apple ID) → Manage Certificates →
#        "+" → Developer ID Application.   (or create one at developer.apple.com)
#   2. Store a notary credential in your keychain so you never paste it again:
#        xcrun notarytool store-credentials free-dev-notary \
#          --apple-id "you@example.com" \
#          --team-id  "ABCDE12345" \
#          --password "xxxx-xxxx-xxxx-xxxx"   # app-specific pw from appleid.apple.com
#   3. Set your Team ID below or export it:  export DEVELOPMENT_TEAM=ABCDE12345
#
# ── Then just run ────────────────────────────────────────────────────────────
#   ./notarize.sh
#
set -euo pipefail
cd "$(dirname "$0")"

TEAM_ID="${DEVELOPMENT_TEAM:-S2NBGK85WD}"         # Apple Team ID (public, not a secret)
NOTARY_PROFILE="${NOTARY_PROFILE:-free-dev-notary}"
SCHEME="FreeDev"
APP_NAME="FreeDev"
VOL_NAME="Free Dev"

BUILD="$PWD/.build/notarize"
ARCHIVE="$BUILD/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD/export"
APP="$EXPORT_DIR/$APP_NAME.app"
DMG="$PWD/$APP_NAME.dmg"

if [[ "$TEAM_ID" == "CHANGE_ME" ]]; then
  echo "✗ Set your Apple Team ID first:  export DEVELOPMENT_TEAM=ABCDE12345"
  echo "  (find it at https://developer.apple.com/account → Membership)"
  exit 1
fi

rm -rf "$BUILD"; mkdir -p "$BUILD"

echo "▸ Archiving (Release)…"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
  archive

echo "▸ Exporting Developer ID app…"
cat > "$BUILD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD/ExportOptions.plist" -exportPath "$EXPORT_DIR"

echo "▸ Submitting to Apple notary service (a few minutes)…"
ZIP="$BUILD/$APP_NAME.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ Stapling the ticket…"
xcrun stapler staple "$APP"

echo "▸ Building DMG…"
STAGE="$BUILD/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "▸ Notarizing the DMG…"   # the DMG needs its own ticket before it can be stapled
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo
echo "✅ Notarized & stapled: $DMG"
echo "   Gatekeeper check:  spctl -a -vvv -t install \"$APP\""
echo
echo "── For the Homebrew cask, update Casks/free-dev.rb with: ────────────────"
echo "   version \"$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo 1.0.0)\""
echo "   sha256  \"$(shasum -a 256 "$DMG" | awk '{print $1}')\""
echo
echo "── Then publish the release: ────────────────────────────────────────────"
echo "   gh release create v1.0.0 \"$DMG\" -t \"Free Dev 1.0\" --notes \"...\""
