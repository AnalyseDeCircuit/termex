<p align="center">  
  <h1 align="center">Termex</h1>  
  <p align="center"><strong>An open-source, AI-native SSH client built with Rust.</strong></p>  
  <p align="center">以 SSH 协议为底座，打造 AI 时代永不断线的云端智能工作平台。</p>  
  <p align="center">SSH is the wire. What flows through it is your entire AI-powered workflow.</p>  
  <p align="center">Connect from any device. Punch through any network.</p>  
  <p align="center">AI keeps working while you're away. Reconnect, and pick up right where it left off.</p>  
  <p align="center">Devices are temporary. Your workspace is permanent.</p>  
</p>

<p align="center">  
  <a href="#installation">Installation</a> &bull;  
  <a href="#features">Features</a> &bull;  
  <a href="#keyboard-shortcuts">Shortcuts</a> &bull;  
  <a href="#development">Development</a> &bull;  
  <a href="#roadmap">Roadmap</a>  
</p>

---

![](https://raw.githubusercontent.com/zouwei/resource/master/images/moraya/20260329-023219.-image.png)

![](https://raw.githubusercontent.com/zouwei/resource/master/images/moraya/20260329-151239.-image.png)

![](https://raw.githubusercontent.com/zouwei/resource/master/images/moraya/20260402-141840.-image.png)

![](https://raw.githubusercontent.com/zouwei/resource/master/images/moraya/20260410-101142.-image.png)

## Why Termex?

|  | Termius | Tabby | WindTerm | Termex |
| --- | --- | --- | --- | --- |
| Beautiful UI | Yes | Yes | No | **Yes** |
| Native Performance | Yes | No (Electron) | Yes | **Yes (Tauri/Rust)** |
| AI Integrated | No | No | No | **Yes** |
| Free & Open Source | No | Yes | Yes | **Yes (MIT)** |
| Encrypted Config | No | Partial | Partial | **Yes (OS Keychain + AES-256-GCM)** |

## Installation

### Download

Download the latest release for your platform from [GitHub Releases](https://github.com/user/termex/releases/latest):

| Platform | Architecture | Format |
| --- | --- | --- |
| macOS | Apple Silicon (M1/M2/M3) | `.dmg` |
| macOS | Intel | `.dmg` |
| Windows | x64 | `.msi` / `.exe` |
| Linux | x86_64 | `.deb` / `.rpm` / `.AppImage` |
| Linux | aarch64 | `.deb` / `.rpm` |

### macOS GateKeeper Issue

If you see an error like **"Termex is damaged and cannot be opened"** on macOS, run this command in Terminal:

```bash
xattr -cr /Applications/Termex.app
```

This removes the quarantine attribute that macOS adds to unsigned apps. After running this command, you can open Termex normally.

> **Note:** A `fix-macos-gatekeeper.command` script is included in each release for convenience. You can download and run it instead of typing the command manually.

### Build from Source

```bash
git clone https://github.com/user/termex.git
cd termex
pnpm install
pnpm tauri build
```

## Features

- **SSH Terminal** -- WebGL-accelerated xterm.js, multi-tab, 60fps, password & key auth
- **Server Management** -- Tree view with groups, search, drag & drop, encrypted credential storage
- **SFTP File Browser** -- Dual-pane with context menu, drag & drop, copy/cut/paste, chmod, file info
- **SSH Tunnel** -- ProxyJump / bastion host support (multi-level), port forwarding (local/remote/dynamic)
- **AI Assistant** -- Dangerous command detection, command explanation, natural language to shell
- **Local AI** -- Built-in llama-server with 12 GGUF models, fully offline, no API key required
- **Terminal Search** -- In-terminal search (`Cmd+F`), keyword highlighting, cross-tab search (`Cmd+Shift+F`)
- **Customization** -- Dark/Light themes, 6 built-in fonts + custom upload, customizable keybindings
- **Security** -- OS Keychain (macOS/Windows/Linux), AES-256-GCM fallback, SQLCipher encrypted database
- **Config Backup** -- Encrypted export/import (`.termex` format), cross-device migration
- **i18n** -- English and Chinese out of the box

## Tech Stack

```text
Tauri v2 + Rust          Backend, SSH, encryption, storage
Vue 3 + TypeScript       Frontend framework
Element Plus             UI components
Tailwind CSS             Styling
xterm.js (WebGL)         Terminal rendering
SQLCipher                Encrypted local database
russh                    Pure-Rust SSH2 protocol
ring + Argon2id          AES-256-GCM encryption & key derivation
```

## Keyboard Shortcuts

> All shortcuts are fully customizable via **Settings → Keybindings**. Click any shortcut label to enter recording mode and press your desired key combination.

### General

| Action | macOS | Windows / Linux |
| --- | --- | --- |
| New Connection | `Cmd+N` | `Ctrl+N` |
| Open Settings | `Cmd+,` | `Ctrl+,` |
| Toggle Sidebar | `Cmd+\` | `Ctrl+\` |
| Toggle AI Panel | `Cmd+Shift+I` | `Ctrl+Shift+I` |

### Tabs

| Action | macOS | Windows / Linux |
| --- | --- | --- |
| Close Current Tab | `Cmd+W` | `Ctrl+W` |
| Next Tab | `Cmd+Tab` | `Ctrl+Tab` |
| Previous Tab | `Cmd+Shift+Tab` | `Ctrl+Shift+Tab` |
| Go to Tab 1–9 | `Cmd+1` \~ `Cmd+9` | `Ctrl+1` \~ `Ctrl+9` |

### Search

| Action | macOS | Windows / Linux |
| --- | --- | --- |
| Search in Terminal | `Cmd+F` | `Ctrl+F` |
| Search All Tabs | `Cmd+Shift+F` | `Ctrl+Shift+F` |

## Security

### OS Keychain Storage (v0.10.0+)

Termex uses the operating system's native credential manager to protect all sensitive data:

| Platform | Backend | Protection |
| --- | --- | --- |
| macOS | Keychain Services | Hardware-level (Secure Enclave + Touch ID) |
| Windows | Credential Manager (DPAPI) | User login password |
| Linux | Secret Service (GNOME Keyring / KDE Wallet) | User login password |

**How it works:**

- SSH passwords, private key passphrases, and AI API keys are stored in the OS keychain -- never in `termex.db`
- `termex.db` only stores a keychain reference ID (e.g., `termex:ssh:password:{uuid}`)
- Even if `termex.db` is stolen, no credentials are exposed
- No master password required -- the OS login session provides the security boundary
- Fallback: If the OS keychain is unavailable (headless Linux), Termex falls back to AES-256-GCM encryption with a user-provided master password

### Additional Security Measures

- Credential fields encrypted with **AES-256-GCM** (ring crate) in fallback mode
- Fallback master password derived via **Argon2id** (m=64MB, t=3, p=4)
- Database encrypted with **SQLCipher**
- AI requests **never** include passwords, keys, or tokens
- No telemetry, no analytics, no phone-home

## Project Structure

```text
termex/
├── .github/workflows/         # CI + cross-platform release
├── docs/                      # Requirements, design, prototype
│   └── iterations/            #   Version iteration plans (v0.1.0 ~ v0.9.0)
├── scripts/                   # Version bump utilities
├── src-tauri/src/             # Rust backend
│   ├── commands/              #   Tauri IPC handlers (58 commands)
│   ├── ssh/                   #   SSH session, auth, port forwarding
│   ├── sftp/                  #   SFTP file operations
│   ├── crypto/                #   AES-256-GCM, Argon2id KDF
│   ├── storage/               #   SQLCipher database, migrations, models
│   ├── ai/                    #   AI provider abstraction, danger detection
│   ├── recording/             #   Session recording (asciicast v2)
│   ├── plugin/                #   Plugin manifest & registry
│   └── state.rs               #   Global AppState
└── src/                       # Vue 3 frontend
    ├── components/            #   sidebar/, terminal/, settings/, sftp/, ai/
    ├── composables/           #   useTerminal, useShortcuts
    ├── stores/                #   server, session, settings, sftp, ai, portForward
    ├── i18n/                  #   zh-CN, en-US
    ├── types/                 #   TypeScript definitions
    └── utils/                 #   Tauri IPC wrappers
```

## Development

### Prerequisites

- [Rust](https://rustup.rs/) (stable)
- [Node.js](https://nodejs.org/) (22+)
- [pnpm](https://pnpm.io/) (10+)
- Platform-specific [Tauri v2 dependencies](https://v2.tauri.app/start/prerequisites/)

### Setup

```bash
git clone https://github.com/user/termex.git
cd termex
pnpm install
pnpm tauri dev
```

### Commands

| Command | Description |
| --- | --- |
| `pnpm tauri dev` | Start dev server with hot reload |
| `pnpm tauri build` | Build production app |
| `pnpm dev` | Start frontend dev server only (Vite) |
| `pnpm run build` | Type-check + build frontend |
| `cd src-tauri && cargo test` | Run Rust tests (45 tests) |
| `cd src-tauri && cargo clippy` | Lint Rust code |
| `pnpm version:bump patch` | Bump version (patch/minor/major/x.y.z) |

### Debug & Launch

```bash
# Full-stack development (frontend + Rust backend with hot reload)
pnpm tauri dev

# Frontend only (no Rust backend, useful for UI work)
pnpm dev

# Run Rust backend tests
cd src-tauri && cargo test

# Run with verbose Rust logging
RUST_LOG=debug pnpm tauri dev

# Build production binary
pnpm tauri build

# Build in debug mode (faster compile, larger binary)
pnpm tauri build --debug
```

### Version Release

```bash
# Semantic version bump (syncs package.json, Cargo.toml, tauri.conf.json)
pnpm version:bump patch         # 0.1.0 → 0.1.1
pnpm version:bump minor         # 0.1.0 → 0.2.0
pnpm version:bump major         # 0.1.0 → 1.0.0
pnpm version:bump 0.2.0         # explicit version

# Commit and tag
git add -A && git commit -m "chore: release v0.2.0"
git tag v0.2.0
git push origin main --tags     # triggers GitHub Actions build
```

## Roadmap

### Shipped

- [x] v0.1.0 -- MVP (SSH + Terminal + Server Management + Encrypted Storage)
- [x] v0.2.0 -- SFTP File Browser
- [x] v0.3.0 -- Port Forwarding + Config Export/Import
- [x] v0.4.0 -- Theme System + Settings Persistence + UX Polish
- [x] v0.5.0 -- AI Core: Danger Detection + Command Explanation
- [x] v0.6.0 -- AI Advanced: NL2Cmd + Smart Autocomplete
- [x] v0.7.0 -- Session Recording + Server Monitoring
- [x] v0.8.0 -- Plugin System + Extensibility
- [x] v0.9.0 -- Stable Release
- [x] v0.10.0 -- OS Keychain Security (credential protection)
- [x] v0.11.0 -- Local AI Models (llama-server, 12 GGUF models, fully offline)
- [x] v0.12.0 -- SSH ProxyJump & Bastion (multi-level jump, connection pooling, SSH Agent)
- [x] v0.13.0 -- SFTP Enhancement (context menu, clipboard ops, chmod, file info)
- [x] v0.14.0 -- Font Management (6 built-in fonts, custom upload, live reload)
- [x] v0.15.0 -- Terminal Search (in-terminal + keyword highlighting + cross-tab)
- [x] v0.16.0 -- Custom Keybindings (record mode, conflict detection, persist)
- [x] v0.17.0 -- Server-to-Server SFTP (direct file transfer between remotes)
- [x] v0.18.0 -- Network Proxy (SOCKS5/4, HTTP/HTTPS CONNECT, mTLS, proxy+bastion chain)
- [x] v0.19.0 -- SFTP Per-Tab (per-tab instances, layout switching, CWD sync)
- [x] v0.20.0 -- Tor Proxy + tmux Sessions + Git Auto Sync
- [x] v0.21.0 -- SSH Dynamic Port Forwarding (SOCKS5 proxy, `ssh -D`)
- [x] v0.22.0 -- ProxyCommand (Cloudflare Tunnel, custom transport)
- [x] v0.23.0 -- Portable Mode (USB drive, data relative to exe)
- [x] v0.24.0 -- Connection Chain (multi-hop any-order, SOCKS5 exit routing)
- [x] v0.25.0 -- Security Compliance (GDPR / ISO 27001 / GB/T 22239, audit logging)
- [x] v0.26.0 -- AI Smart Autocomplete (inline ghost text, context-aware, local AI priority)
- [x] v0.27.0 -- **SSH Config Import + Snippet Manager** (one-click `~/.ssh/config` import, command snippets with variable templates, quick palette)
- [x] v0.28.0 -- **Server Monitoring Dashboard** (real-time CPU/Memory/Disk/Network via SSH exec, process Top N, sparkline charts, threshold alerts)
- [x] v0.29.0 -- **Session Recording + AI Summary** (asciicast v2 record/playback, speed control, AI-generated session summary)
- [x] v0.30.0 -- **Team Collaboration v1** (Git-based config sharing, team encryption, selective sharing, role-based access)
- [x] v0.31.0 -- **AI Operations Assistant** (context-aware chat, error auto-diagnosis, multi-turn troubleshooting, command orchestration)
- [x] v0.32.0 -- **Terminal Split Pane** (horizontal/vertical split, broadcast input to all panes, focus navigation)
- [x] v0.33.0 -- **Cloud Native Integration** (kubectl exec, AWS SSM, K8s pod browser, container log streaming)

### Desktop — Planned

- [ ] v0.34.0 -- **Team Collaboration v2** (fine-grained role permissions, audit dashboard, conflict resolution UI)
- [ ] v0.35.0 -- Desktop v1.0 Stable (performance optimization, stability polish)

### Mobile — Planned

- [ ] v0.40.0 -- Mobile Foundation (Tauri mobile init, minimal SSH client on iOS/Android)
- [ ] v0.42.0 -- Mobile Server Management + SFTP + Cross-Device Sync
- [ ] v0.44.0 -- Mobile AI + Native Keychain (iOS Keychain / Android Keystore)
- [ ] v0.46.0 -- Mobile Polish + App Store / Google Play Release

## Contributing

Contributions are welcome! Please open an issue before submitting large PRs.

## License

[MIT](LICENSE)