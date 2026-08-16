#!/usr/bin/env bash
# Signs the built macOS .app bundle with a Developer ID certificate.
#
# Runs as a flutter_distributor `prepackage` hook, i.e. after `flutter build
# macos` and before the DMG is assembled. That ordering is the whole point:
# signing the bundle after packaging leaves the copy *inside* the DMG
# unsigned, which still passes a local `codesign --verify` of the on-disk
# bundle while Apple rejects the submission with "The binary is not signed
# with a valid Developer ID certificate" for every nested framework.
#
# Required env:
#   SIGN_ID   "Developer ID Application: ..." certificate common name
#
# Invoked from app/ (the Flutter project root), so paths are resolved from
# this script's own location rather than the working directory.
set -euo pipefail

: "${SIGN_ID:?SIGN_ID not set}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/app/build/macos/Build/Products/Release"
ENTITLEMENTS="$REPO_ROOT/app/macos/Runner/Release.entitlements"

APP="$(find "$BUILD_DIR" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null || true)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "✗ no .app bundle found under $BUILD_DIR" >&2
  exit 1
fi
echo "→ signing app bundle: $APP"

# Nested code is signed inner-most first: signing a container seals whatever
# it holds, so anything signed afterwards would be left outside the seal.
# `--deep` is not a substitute — Apple deprecated it because it applies
# neither entitlements nor the hardened runtime to nested code.
find "$APP" -type f \( -name '*.dylib' -o -name '*.so' \) -print0 |
  while IFS= read -r -d '' lib; do
    codesign --force --sign "$SIGN_ID" --timestamp --options runtime "$lib"
  done

# Remaining Mach-O executables: helper tools and bundled sidecars. An
# unsigned executable anywhere in the bundle fails notarization on its own.
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

echo "→ signing bundle itself"
codesign --force --sign "$SIGN_ID" --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS" "$APP"

echo "→ verifying"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "✓ app bundle signed: $APP"
