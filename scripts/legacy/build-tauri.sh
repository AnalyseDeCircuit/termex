#!/usr/bin/env bash
#
# Manual Tauri/Vue desktop-build recipe, captured for the v0.78.0–v0.80.0
# retirement window. From v0.78.0 onward CI no longer builds src-tauri/;
# this script lets you reproduce a Tauri binary locally when you need to:
#
#   * verify a v0.77.x regression against the legacy stack;
#   * produce a one-off Tauri DMG for a user who hasn't migrated;
#   * preserve a forensic build before the v0.80.0 physical deletion.
#
# The script intentionally lives OUTSIDE the workspace's normal scripts
# (note the `legacy/` subdir) so contributors who run `ls scripts/` won't
# stumble onto it as a current workflow. There is no CI integration —
# you call it by hand:
#
#     scripts/legacy/build-tauri.sh debug      # fast iterative build
#     scripts/legacy/build-tauri.sh release    # full release build
#     scripts/legacy/build-tauri.sh notarize   # release + macOS notarize
#
# Pre-requisites (one-time):
#   * pnpm install                    # restore frontend deps (Vue/Vite)
#   * rustup default stable           # Rust toolchain
#   * Tauri prereqs from https://tauri.app/start/prerequisites/
#
# After v0.80.0 (when src-tauri/ is deleted) this script will exit with
# an explanatory error pointing at the git history.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -d "src-tauri" ]]; then
  cat <<EOF >&2
❌ src-tauri/ is gone. The Tauri/Vue stack was physically removed; this
   script no longer applies. To inspect or rebuild the legacy stack,
   check out a tag <= v0.79.x:

     git checkout v0.77.0
     scripts/legacy/build-tauri.sh "\$@"

EOF
  exit 1
fi

MODE="${1:-debug}"

case "$MODE" in
  debug)
    echo "▶ Building Tauri DEBUG binary (iterative, no notarize)…"
    pnpm install
    pnpm tauri build --debug
    ;;
  release)
    echo "▶ Building Tauri RELEASE binary (no notarize)…"
    pnpm install
    pnpm tauri build
    ;;
  notarize)
    if [[ "$(uname -s)" != "Darwin" ]]; then
      echo "❌ notarize mode only works on macOS" >&2
      exit 1
    fi
    echo "▶ Building + notarizing macOS release…"
    pnpm install
    pnpm tauri build
    scripts/sign-macos.sh src-tauri/target/release/bundle/dmg/*.dmg
    ;;
  *)
    echo "Usage: $0 {debug|release|notarize}" >&2
    exit 1
    ;;
esac

echo "✅ Done. Artefacts under src-tauri/target/release/bundle/"
