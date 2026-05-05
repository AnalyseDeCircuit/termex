#!/usr/bin/env bash
# macOS Developer ID signing + Apple Notary submission for Termex.
#
# Required env vars (set as GitHub Action secrets):
#   APPLE_ID          Apple ID email used for notarization
#   APP_PASSWORD      App-specific password for notarization
#   TEAM_ID           10-char Apple team id
#   SIGN_ID           "Developer ID Application: ..." certificate common name
#   DMG_PATH          Absolute path to the DMG to sign/notarize
#
# Exit code 0 = signed + notarized + stapled.
set -euo pipefail

: "${APPLE_ID:?APPLE_ID not set}"
: "${APP_PASSWORD:?APP_PASSWORD not set}"
: "${TEAM_ID:?TEAM_ID not set}"
: "${SIGN_ID:?SIGN_ID not set}"
: "${DMG_PATH:?DMG_PATH not set}"

APP="build/macos/Build/Products/Release/Termex.app"
ENTITLEMENTS="src-tauri/entitlements.plist"

if [[ -d "$APP" ]]; then
  echo "→ signing inner binaries in $APP"
  find "$APP" -name "*.dylib" -type f -print0 | while IFS= read -r -d '' lib; do
    codesign --force --sign "$SIGN_ID" --timestamp --options runtime "$lib"
  done
  find "$APP" -name "*.framework" -type d -print0 | while IFS= read -r -d '' fw; do
    codesign --force --sign "$SIGN_ID" --timestamp --options runtime "$fw"
  done

  echo "→ signing app bundle"
  codesign --force --deep --sign "$SIGN_ID" --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS" "$APP"
fi

echo "→ signing DMG: $DMG_PATH"
codesign --force --sign "$SIGN_ID" --timestamp "$DMG_PATH"

echo "→ submitting for notarization"
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_PASSWORD" \
  --wait

echo "→ stapling ticket"
xcrun stapler staple "$DMG_PATH"

echo "✓ macOS signing complete: $DMG_PATH"
