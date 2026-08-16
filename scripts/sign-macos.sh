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
  # Nested code must be signed inner-most first: re-signing a container
  # invalidates signatures applied to it afterwards. `--deep` is not a
  # substitute — Apple deprecated it precisely because it does not apply the
  # right entitlements or hardened-runtime flags to nested binaries, and
  # notarization rejects the result.
  echo "→ signing nested binaries in $APP"
  find "$APP" -type f \( -name '*.dylib' -o -name '*.so' \) -print0 |
    while IFS= read -r -d '' lib; do
      codesign --force --sign "$SIGN_ID" --timestamp --options runtime "$lib"
    done

  # Any remaining Mach-O executable that is not a dylib — helper tools and
  # bundled binaries such as the llama-server sidecar. Unsigned executables
  # anywhere in the bundle are a notarization failure on their own.
  find "$APP" -type f -perm -u+x -print0 |
    while IFS= read -r -d '' bin; do
      case "$bin" in *.dylib|*.so) continue;; esac
      file -b "$bin" | grep -q "Mach-O" || continue
      codesign --force --sign "$SIGN_ID" --timestamp --options runtime "$bin"
    done

  find "$APP" -name '*.framework' -type d -print0 |
    while IFS= read -r -d '' fw; do
      codesign --force --sign "$SIGN_ID" --timestamp --options runtime "$fw"
    done

  echo "→ signing app bundle"
  codesign --force --sign "$SIGN_ID" --timestamp --options runtime \
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
# `notarytool submit --wait` exits 0 for a rejected submission: a non-zero
# exit means the upload failed, not that the artefact was accepted. Without
# this check the script walked straight past a rejection into stapling, and
# the only clue was a stray "status: Invalid" in the log.
SUBMIT_OUTPUT="$(
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait 2>&1
)"
echo "$SUBMIT_OUTPUT"

SUBMISSION_ID="$(awk '/^ *id: /{print $2; exit}' <<<"$SUBMIT_OUTPUT")"
STATUS="$(awk '/^ *status: /{print $2; exit}' <<<"$SUBMIT_OUTPUT")"

if [[ "$STATUS" != "Accepted" ]]; then
  echo "✗ notarization returned '$STATUS' — fetching Apple's reasons:" >&2
  if [[ -n "$SUBMISSION_ID" ]]; then
    xcrun notarytool log "$SUBMISSION_ID" \
      --apple-id "$APPLE_ID" \
      --team-id "$TEAM_ID" \
      --password "$APP_PASSWORD" >&2 || true
  fi
  exit 1
fi

echo "→ stapling ticket"
xcrun stapler staple "$DMG_PATH"

echo "✓ macOS signing complete: $DMG_PATH"
