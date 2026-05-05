#!/usr/bin/env bash
#
# flutter_rust_bridge codegen runner
#
# Generates Dart bindings from crates/termex-flutter-bridge/src/api/*.rs
# into app/lib/src/frb_generated/.
#
# Requirements:
#   - Rust toolchain (stable)
#   - Flutter SDK (>= 3.24)
#   - flutter_rust_bridge_codegen (cargo install --version '^2.0')
#
# Usage:
#   ./scripts/frb-codegen.sh          # regenerate bindings
#   ./scripts/frb-codegen.sh --check  # verify current bindings are up-to-date (CI)

set -euo pipefail

cd "$(dirname "$0")/.."

# ── Tool checks ──
if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo "❌ flutter_rust_bridge_codegen not installed."
  echo "   Run: cargo install flutter_rust_bridge_codegen --version '^2.0'"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ flutter not on PATH. Install via https://docs.flutter.dev/get-started/install"
  exit 1
fi

# ── Flutter pub get (needed for codegen to resolve types) ──
(cd app && flutter pub get >/dev/null)

# ── Run codegen ──
CHECK_MODE=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=1
fi

echo "▶ Generating FRB bindings..."
flutter_rust_bridge_codegen generate

if [[ $CHECK_MODE -eq 1 ]]; then
  if ! git diff --exit-code -- app/lib/src/ crates/termex-flutter-bridge/include/ 2>/dev/null; then
    echo "❌ FRB bindings are out of date. Run ./scripts/frb-codegen.sh locally and commit."
    exit 1
  fi
  echo "✅ FRB bindings are up-to-date."
else
  echo "✅ Regenerated FRB bindings."
  echo "   Review changes with: git diff app/lib/src/"
fi
