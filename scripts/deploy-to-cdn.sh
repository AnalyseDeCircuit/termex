#!/usr/bin/env bash
# Upload signed release artifacts + SHA256SUMS to the Termex CDN.
#
# Env:
#   ASSETS_DIR      directory containing termex-<version>-<platform>-<arch>.* files
#   CDN_BUCKET      s3://-style bucket URL (default s3://termex-releases)
#   CHANNEL         stable | beta | stable-legacy (default stable)
#   VERSION         release version (required)
set -euo pipefail

: "${VERSION:?VERSION not set}"
ASSETS_DIR="${ASSETS_DIR:-./release}"
CDN_BUCKET="${CDN_BUCKET:-s3://termex-releases}"
CHANNEL="${CHANNEL:-stable}"

cd "$ASSETS_DIR"

echo "→ generating SHA256SUMS"
sums="termex-${VERSION}-SHA256SUMS.txt"
shasum -a 256 termex-${VERSION}-*.* > "$sums"

if ! command -v aws >/dev/null 2>&1; then
  echo "❌ aws CLI not installed" >&2
  exit 1
fi

echo "→ uploading release assets to ${CDN_BUCKET}/downloads/${CHANNEL}/"
for f in termex-${VERSION}-*.*; do
  aws s3 cp "$f" "${CDN_BUCKET}/downloads/${CHANNEL}/$f" \
    --cache-control "max-age=31536000, public"
done

echo "✓ deployment complete"
