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

# v0.78.0 PC cutover: paths point to the Flutter macOS build outputs.
# Tauri build outputs live under src-tauri/target/release/bundle/macos/
# and are only produced when scripts/legacy/build-tauri.sh runs by hand.
#
# The bundle name is discovered rather than hardcoded: Flutter derives it from
# the pubspec name, so the build emits `termex.app` in lower case. The literal
# "Termex.app" this used to look for only resolved because macOS volumes are
# case-insensitive by default — on a case-sensitive volume the inner binaries
# would silently go unsigned, and notarization would then reject the DMG.
BUILD_DIR="app/build/macos/Build/Products/Release"
APP="$(find "$BUILD_DIR" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null || true)"
ENTITLEMENTS="app/macos/Runner/Release.entitlements"

if [[ -n "$APP" && -d "$APP" ]]; then
  echo "→ found app bundle: $APP"
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
else
  # Signing only the DMG leaves an unsigned app inside it: Gatekeeper still
  # blocks the app after mounting, and notarization rejects the submission.
  # Fail loudly rather than shipping a DMG that looks signed and is not.
  echo "✗ no .app bundle found under $BUILD_DIR — refusing to sign a DMG" >&2
  echo "  around an unsigned app. Run 'flutter build macos --release' first." >&2
  exit 1
fi

# Confirm the bundle really is signed and hardened before paying for a
# notarization round-trip, which otherwise fails several minutes later.
echo "→ verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

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
