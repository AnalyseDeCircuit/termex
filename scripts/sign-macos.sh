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

# The app bundle is signed earlier, by scripts/sign-macos-app.sh running as a
# flutter_distributor prepackage hook. It has to happen before the DMG is
# assembled: signing the bundle afterwards leaves the copy inside the DMG
# untouched, which still satisfies a local `codesign --verify` of the on-disk
# bundle while Apple rejects every nested framework as unsigned.
#
# Verify the payload actually carries a signature before spending a
# notarization round-trip on it, so that ordering mistake cannot silently
# return.
echo "→ verifying the app inside the DMG is signed"
MOUNT_POINT="$(mktemp -d)"
hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
trap 'hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true' EXIT

EMBEDDED_APP="$(find "$MOUNT_POINT" -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$EMBEDDED_APP" ]]; then
  echo "✗ no .app inside $DMG_PATH" >&2
  exit 1
fi
if ! codesign --verify --deep --strict "$EMBEDDED_APP" 2>&1; then
  echo "✗ the app inside the DMG is not properly signed — notarization would" >&2
  echo "  fail. Check that the prepackage hook ran before packaging." >&2
  exit 1
fi
echo "✓ payload signature verified"

hdiutil detach "$MOUNT_POINT" -quiet
trap - EXIT

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
