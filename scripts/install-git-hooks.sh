#!/usr/bin/env bash
#
# Termex git-hooks installer (v0.79.45)
#
# One-time opt-in: points git at the repo-tracked `.githooks/` directory
# so every contributor's commit runs the same hook set without each
# having to hand-symlink files into `.git/hooks/`.
#
# Idempotent — re-run is a no-op.
#
# To uninstall: `git config --unset core.hooksPath`

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

HOOKS_DIR=".githooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
  echo "❌ Expected $HOOKS_DIR/ to exist at repo root — re-clone or check git history."
  exit 1
fi

# Sanity: make every hook executable. Catches the common "I edited the
# file in an editor that stripped +x" footgun.
chmod +x "$HOOKS_DIR"/* 2>/dev/null || true

git config core.hooksPath "$HOOKS_DIR"

echo "✅ Git hooks enabled. Path = $(git config core.hooksPath)"
echo "   Installed hooks:"
for f in "$HOOKS_DIR"/*; do
  [[ -f "$f" ]] || continue
  echo "   - $(basename "$f")"
done
echo
echo "Bypass any hook with \`git commit --no-verify\`."
