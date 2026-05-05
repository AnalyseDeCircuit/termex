#!/usr/bin/env bash
# Regenerate appcast.xml for the given channel + version and upload to CDN.
#
# Env / args:
#   $1              VERSION (e.g. 0.49.0)
#   CHANNEL         stable | beta | stable-legacy (default: stable)
#   ASSETS_DIR      local directory with the release artifacts
#   CDN_BUCKET      S3 bucket (or s3://-style URL) to publish to
set -euo pipefail

VERSION="${1:?usage: update-appcast.sh <version>}"
CHANNEL="${CHANNEL:-stable}"
ASSETS_DIR="${ASSETS_DIR:-./release}"
CDN_BUCKET="${CDN_BUCKET:-s3://termex-releases}"

out="$(mktemp -d)/appcast.xml"
pubdate="$(date -u +'%a, %d %b %Y %H:%M:%S +0000')"

size_of() {
  if stat --version >/dev/null 2>&1; then
    stat -c '%s' "$1"
  else
    stat -f '%z' "$1"
  fi
}

dmg="${ASSETS_DIR}/termex-${VERSION}-macos-arm64.dmg"
if [[ ! -f "$dmg" ]]; then
  echo "❌ missing asset: $dmg" >&2
  exit 1
fi
dmg_size=$(size_of "$dmg")

cat > "$out" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Termex ${CHANNEL}</title>
    <item>
      <title>Termex ${VERSION}</title>
      <pubDate>${pubdate}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://termex.app/releases/${VERSION}</sparkle:releaseNotesLink>
      <enclosure
        url="https://termex.app/downloads/${CHANNEL}/termex-${VERSION}-macos-arm64.dmg"
        length="${dmg_size}"
        type="application/x-apple-diskimage"/>
    </item>
  </channel>
</rss>
XML

echo "→ generated appcast.xml at $out"

if command -v aws >/dev/null 2>&1; then
  aws s3 cp "$out" "${CDN_BUCKET}/updates/${CHANNEL}/appcast.xml" \
    --cache-control "max-age=300, public"
  echo "✓ uploaded to ${CDN_BUCKET}/updates/${CHANNEL}/appcast.xml"
else
  echo "⚠ aws CLI not found; appcast.xml left at $out"
fi
