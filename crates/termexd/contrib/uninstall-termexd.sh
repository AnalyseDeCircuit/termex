#!/usr/bin/env bash
# Termex daemon uninstaller.
# Removes the binary, the systemd unit / launchd plist, and (with
# --purge) the data directory (~/.termex including task history).
set -euo pipefail

PREFIX="${TERMEXD_PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
DATA_DIR="$HOME/.termex"
PURGE=0
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
  esac
done

log() { printf "\033[1;34m[termexd]\033[0m %s\n" "$*"; }

# Stop services
if systemctl --user is-active --quiet termexd 2>/dev/null; then
  systemctl --user disable --now termexd.service
  rm -f "$HOME/.config/systemd/user/termexd.service"
  systemctl --user daemon-reload
  log "removed systemd user unit"
fi

PLIST="$HOME/Library/LaunchAgents/dev.termex.daemon.plist"
if [ -f "$PLIST" ]; then
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  log "removed launchd agent"
fi

# Kill any straggler
if [ -f "$DATA_DIR/termexd.pid" ]; then
  kill -TERM "$(cat "$DATA_DIR/termexd.pid")" 2>/dev/null || true
  rm -f "$DATA_DIR/termexd.pid"
fi

# Remove binary
if [ -f "$BIN_DIR/termexd" ]; then
  rm -f "$BIN_DIR/termexd"
  log "removed $BIN_DIR/termexd"
fi

# Optionally purge data
if [ "$PURGE" = "1" ]; then
  rm -rf "$DATA_DIR"
  log "purged $DATA_DIR (task history gone)"
else
  log "data dir kept at $DATA_DIR (pass --purge to remove)"
fi

log "✓ termexd uninstalled"
