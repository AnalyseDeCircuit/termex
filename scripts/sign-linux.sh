#!/usr/bin/env bash
# GPG detach-sign Linux AppImage.
#
# Required env:
#   GPG_KEY_ID    fingerprint or email identifying the signing key
#   APPIMAGE_PATH path to the AppImage
set -euo pipefail

: "${GPG_KEY_ID:?GPG_KEY_ID not set}"
: "${APPIMAGE_PATH:?APPIMAGE_PATH not set}"

SIG_PATH="${APPIMAGE_PATH}.sig"

echo "→ signing $APPIMAGE_PATH with $GPG_KEY_ID"
gpg --batch --yes --local-user "$GPG_KEY_ID" \
    --output "$SIG_PATH" \
    --detach-sig "$APPIMAGE_PATH"

echo "→ verifying signature"
gpg --verify "$SIG_PATH" "$APPIMAGE_PATH"

echo "✓ Linux GPG signing complete: $SIG_PATH"
