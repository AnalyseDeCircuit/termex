#!/usr/bin/env bash
# One-shot release driver — bumps versions across all files, commits,
# tags, and pushes.  CI takes over from the tag push.
#
# Usage: ./scripts/release.sh <version>
#   <version>  explicit semver (e.g. 0.49.0) or bump keyword (patch/minor/major)
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <patch|minor|major|x.y.z>" >&2
  exit 1
fi

BUMP="$1"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "❌ working tree not clean — commit or stash first." >&2
  exit 1
fi

echo "→ bumping version ($BUMP)"
node scripts/bump-version.mjs "$BUMP"

VERSION="$(node -p "require('./package.json').version")"
TAG="v${VERSION}"

echo "→ committing"
git add -A
git commit -m "chore: release ${TAG}"

echo "→ tagging"
git tag -a "$TAG" -m "Termex ${TAG}"

echo "→ pushing"
git push origin main
git push origin "$TAG"

echo "✓ ${TAG} released.  CI (flutter-release.yml) will now build + sign."
