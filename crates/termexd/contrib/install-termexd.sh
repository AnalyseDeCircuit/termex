#!/usr/bin/env bash
# Termex daemon installer
# Usage: curl -sSL https://termex.dev/install-termexd.sh | sh
#
# Env vars:
#   TERMEXD_VERSION  (default: latest)
#   TERMEXD_PREFIX   (default: $HOME/.local)
#   TERMEXD_MIRROR   (default: https://github.com/zouwei/termex)
#   TERMEXD_SERVICE  (default: prompt — choose systemd / launchd / none)
set -euo pipefail

VERSION="${TERMEXD_VERSION:-latest}"
PREFIX="${TERMEXD_PREFIX:-$HOME/.local}"
MIRROR="${TERMEXD_MIRROR:-https://github.com/zouwei/termex}"
SERVICE="${TERMEXD_SERVICE:-prompt}"
BIN_DIR="$PREFIX/bin"
DATA_DIR="$HOME/.termex"

# Pretty output
log()  { printf "\033[1;34m[termexd]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[termexd ERROR]\033[0m %s\n" "$*" >&2; }
warn() { printf "\033[1;33m[termexd WARN]\033[0m %s\n" "$*"; }

# ── 1. Detect arch + OS ─────────────────────────────────────────────
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  ARCH="x86_64" ;;
  aarch64|arm64) ARCH="aarch64" ;;
  *) err "unsupported arch: $ARCH"; exit 1 ;;
esac
case "$OS" in
  linux)  TARGET="${ARCH}-unknown-linux-musl" ;;
  darwin) TARGET="${ARCH}-apple-darwin" ;;
  *) err "unsupported OS: $OS (only linux + macOS)"; exit 1 ;;
esac
log "detected target: $TARGET"

# ── 2. Resolve version ──────────────────────────────────────────────
if [ "$VERSION" = "latest" ]; then
  log "querying latest release..."
  api_url="${MIRROR/github.com/api.github.com/repos}/releases/latest"
  VERSION=$(curl -fsSL "$api_url" \
    | grep '"tag_name"' | head -1 | cut -d '"' -f 4 | sed 's/^v//')
  if [ -z "$VERSION" ]; then
    err "could not resolve latest version; pass TERMEXD_VERSION=x.y.z"
    exit 1
  fi
fi
log "version: $VERSION"

# ── 3. Download + verify ────────────────────────────────────────────
TARBALL="termexd-${VERSION}-${TARGET}.tar.gz"
URL="$MIRROR/releases/download/v${VERSION}/${TARBALL}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log "downloading $URL ..."
if ! curl -fsSL "$URL" -o "$TMP/$TARBALL"; then
  err "download failed; check network or TERMEXD_MIRROR"
  exit 1
fi
log "verifying checksum..."
if curl -fsSL "${URL}.sha256" -o "$TMP/${TARBALL}.sha256"; then
  if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$TMP" && sha256sum -c "${TARBALL}.sha256" )
  elif command -v shasum >/dev/null 2>&1; then
    expected=$(awk '{print $1}' "$TMP/${TARBALL}.sha256")
    actual=$(shasum -a 256 "$TMP/$TARBALL" | awk '{print $1}')
    if [ "$expected" != "$actual" ]; then
      err "checksum mismatch"; exit 1
    fi
  else
    warn "no sha256sum/shasum found; skipping checksum verification"
  fi
else
  warn "no .sha256 sidecar; skipping checksum verification"
fi

# ── 4. Install ──────────────────────────────────────────────────────
mkdir -p "$BIN_DIR" "$DATA_DIR"
log "extracting to $BIN_DIR ..."
tar -xzf "$TMP/$TARBALL" -C "$TMP"
mv "$TMP/termexd" "$BIN_DIR/"
chmod +x "$BIN_DIR/termexd"
log "installed: $BIN_DIR/termexd"

# ── 5. PATH hint ────────────────────────────────────────────────────
if ! echo ":$PATH:" | grep -q ":$BIN_DIR:"; then
  warn "$BIN_DIR is not on PATH"
  case "$SHELL" in
    *zsh*)  rc=~/.zshrc ;;
    *bash*) rc=~/.bashrc ;;
    *fish*) rc=~/.config/fish/config.fish ;;
    *)      rc="~/.profile" ;;
  esac
  log "  echo 'export PATH=$BIN_DIR:\$PATH' >> $rc"
fi

# ── 6. Service install (optional) ───────────────────────────────────
prompt_service() {
  echo ""
  log "Install as system service?"
  case "$OS" in
    linux)  echo "  1) systemd (recommended on Linux)"; echo "  2) none" ;;
    darwin) echo "  1) launchd (recommended on macOS)"; echo "  2) none" ;;
  esac
  printf "Choice [1]: "
  read -r choice
  case "${choice:-1}" in
    1) [ "$OS" = "linux" ] && echo "systemd" || echo "launchd" ;;
    *) echo "none" ;;
  esac
}

install_systemd() {
  UNIT_DIR="$HOME/.config/systemd/user"
  mkdir -p "$UNIT_DIR"
  cat > "$UNIT_DIR/termexd.service" <<EOF
[Unit]
Description=Termex remote daemon
After=network.target

[Service]
ExecStart=$BIN_DIR/termexd
Restart=on-failure
RestartSec=5
StandardOutput=append:$DATA_DIR/termexd.log
StandardError=append:$DATA_DIR/termexd.log

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now termexd.service
  log "✓ systemd user service installed"
  log "  status: systemctl --user status termexd"
}

install_launchd() {
  PLIST="$HOME/Library/LaunchAgents/dev.termex.daemon.plist"
  mkdir -p "$(dirname "$PLIST")"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>dev.termex.daemon</string>
  <key>ProgramArguments</key>
  <array><string>$BIN_DIR/termexd</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$DATA_DIR/termexd.log</string>
  <key>StandardErrorPath</key><string>$DATA_DIR/termexd.log</string>
</dict>
</plist>
EOF
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load -w "$PLIST"
  log "✓ launchd agent installed"
  log "  status: launchctl list | grep dev.termex"
}

case "$SERVICE" in
  prompt)  SERVICE_CHOICE=$(prompt_service) ;;
  *)       SERVICE_CHOICE="$SERVICE" ;;
esac

case "$SERVICE_CHOICE" in
  systemd)  install_systemd ;;
  launchd)  install_launchd ;;
  none|"")  log "no service installed. start manually: $BIN_DIR/termexd" ;;
  *)        warn "unknown service '$SERVICE_CHOICE', skipping" ;;
esac

# ── 7. Done ─────────────────────────────────────────────────────────
echo ""
log "✓ termexd v${VERSION} installed."
log ""
log "The first run will print the bearer token, also saved to:"
log "  $DATA_DIR/daemon.token  (mode 0600)"
log ""
log "Connect from your Termex client by opening an SSH tunnel to"
log "  127.0.0.1:7821 on this host (\`ssh -L <port>:127.0.0.1:7821 ...\`)"
log "and pointing the client at ws://127.0.0.1:<port>/v1/stream with"
log "the token."
