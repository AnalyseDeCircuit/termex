#!/usr/bin/env bash
# parity-launch.sh — v0.77.0 PC final parity A/B harness.
#
# Launches both the legacy Tauri/Vue build and the new Flutter desktop
# build side by side, so they can be exercised on the same machine
# against the same fleet of test servers and visually compared.
#
# Key safety property: the Flutter build is started with
# TERMEX_AUDIT_MODE=true, which makes Rust paths::override_app_data_dir()
# redirect SQLCipher / recordings / fonts / models / bin under
# `~/.termex-flutter-audit/`. The legacy Tauri build keeps using the
# production `dirs::data_dir()` location. Isolation is one-sided —
# legacy DB never sees Flutter writes.
#
# Usage:
#   ./scripts/parity-launch.sh                  # macOS / Linux
#   PLATFORM=linux ./scripts/parity-launch.sh   # force Linux target
#   PLATFORM=macos ./scripts/parity-launch.sh   # force macOS target
#
# Logs go to `parity-logs/{tauri,flutter}.log`. Press Ctrl-C in this
# terminal to send SIGTERM to both child processes.

set -euo pipefail

# --- 0. Repo root sanity -------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f "$REPO_ROOT/Cargo.toml" || ! -d "$REPO_ROOT/app" || ! -d "$REPO_ROOT/src-tauri" ]]; then
  echo "[parity-launch] FATAL: expected to be run from termex repo root" >&2
  exit 1
fi

# --- 1. Detect target platform ------------------------------------------

PLATFORM="${PLATFORM:-}"
if [[ -z "$PLATFORM" ]]; then
  case "$(uname -s)" in
    Darwin) PLATFORM=macos ;;
    Linux)  PLATFORM=linux ;;
    *)      echo "[parity-launch] FATAL: unsupported host OS $(uname -s)" >&2; exit 1 ;;
  esac
fi
echo "[parity-launch] target platform = $PLATFORM"

# --- 2. Tooling presence checks -----------------------------------------

if ! command -v pnpm >/dev/null 2>&1; then
  echo "[parity-launch] FATAL: pnpm not found on PATH" >&2; exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "[parity-launch] FATAL: flutter not found on PATH" >&2; exit 1
fi

# --- 3. Prepare audit data dir ------------------------------------------

AUDIT_DIR="${HOME}/.termex-flutter-audit"
mkdir -p "$AUDIT_DIR"
echo "[parity-launch] Flutter audit data dir = $AUDIT_DIR"
echo "[parity-launch] legacy Tauri keeps default data dir under \$(dirs::data_dir())"

# --- 4. Log dir ---------------------------------------------------------

LOG_DIR="$REPO_ROOT/parity-logs"
mkdir -p "$LOG_DIR"
TAURI_LOG="$LOG_DIR/tauri.log"
FLUTTER_LOG="$LOG_DIR/flutter.log"
: >"$TAURI_LOG"
: >"$FLUTTER_LOG"
echo "[parity-launch] logs: $TAURI_LOG / $FLUTTER_LOG"

# --- 5. Spawn both --------------------------------------------------------

cleanup() {
  echo
  echo "[parity-launch] shutting down both children…"
  if [[ -n "${TAURI_PID:-}" ]]; then
    kill -TERM "$TAURI_PID" 2>/dev/null || true
  fi
  if [[ -n "${FLUTTER_PID:-}" ]]; then
    kill -TERM "$FLUTTER_PID" 2>/dev/null || true
  fi
  wait 2>/dev/null || true
  echo "[parity-launch] done"
}
trap cleanup INT TERM EXIT

echo
echo "[parity-launch] starting legacy Tauri (control group)…"
( cd "$REPO_ROOT" && pnpm tauri dev ) >>"$TAURI_LOG" 2>&1 &
TAURI_PID=$!
echo "[parity-launch] tauri pid = $TAURI_PID"

echo "[parity-launch] starting Flutter desktop (test group, audit mode)…"
case "$PLATFORM" in
  macos)   FLUTTER_DEVICE=macos ;;
  linux)   FLUTTER_DEVICE=linux ;;
esac
(
  cd "$REPO_ROOT/app" && \
  flutter run -d "$FLUTTER_DEVICE" \
    --dart-define=TERMEX_AUDIT_MODE=true
) >>"$FLUTTER_LOG" 2>&1 &
FLUTTER_PID=$!
echo "[parity-launch] flutter pid = $FLUTTER_PID"

echo
echo "[parity-launch] both running. Tail logs:"
echo "  tail -f $TAURI_LOG"
echo "  tail -f $FLUTTER_LOG"
echo
echo "[parity-launch] Ctrl-C here sends SIGTERM to both."

# Wait on either to exit; cleanup trap kills the survivor.
wait -n "$TAURI_PID" "$FLUTTER_PID" 2>/dev/null || true
