#!/usr/bin/env bash
# Userland watchdog for termexd — restarts the daemon if it dies.
# Use this on systems without systemd / launchd. Run in the background:
#   nohup ~/.local/bin/termexd-watchdog.sh > /dev/null 2>&1 &
set -euo pipefail

DATA_DIR="${TERMEXD_DATA_DIR:-$HOME/.termex}"
PID_FILE="$DATA_DIR/termexd.pid"
LOG="$DATA_DIR/termexd.log"
BIN="${TERMEXD_BIN:-$HOME/.local/bin/termexd}"
SLEEP_OK=5     # seconds between liveness checks
RETRY_AFTER=5  # seconds to wait before restart

if [ ! -x "$BIN" ]; then
  echo "$(date) watchdog: $BIN not executable; aborting" >&2
  exit 1
fi
mkdir -p "$DATA_DIR"

while true; do
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    sleep "$SLEEP_OK"
    continue
  fi
  echo "$(date) watchdog: termexd not running, restarting" >> "$LOG"
  nohup "$BIN" >> "$LOG" 2>&1 &
  echo $! > "$PID_FILE"
  sleep "$RETRY_AFTER"
done
