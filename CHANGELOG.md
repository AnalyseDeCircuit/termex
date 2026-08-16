# Changelog

All notable changes to Termex are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v0.53.8] — User-reported bug fixes

Maintenance release on the 0.53.x line, addressing issues reported against the
published build. No new features.

### Fixed

- **Nerd Font glyphs rendered as tofu in the terminal** ([#17](https://github.com/zouwei/termex/issues/17))
  - `buildFontFamilyCSS` only added the `Symbols Nerd Font Mono` fallback when
    the family name matched `/nerd\s*font/`. The Nerd Fonts project ships its
    patched fonts as `MesloLGS NF`, `FiraCode NFM`, `JetBrainsMono NFP` and
    similar, none of which match — so powerline and icon glyphs fell through to
    the generic monospace font. The symbol fallbacks are now always appended;
    CSS only consults them for codepoints the chosen family lacks.
  - Custom font uploads accept `.ttf/.otf/.woff/.woff2`, but every upload was
    wrapped in a Blob hardcoded to `font/woff2`, which WKWebView (macOS)
    rejected. Font bytes are now passed to `FontFace` directly, which also stops
    leaking one object URL per font.
- **Subgroups never appeared in the sidebar** ([#21](https://github.com/zouwei/termex/issues/21))
  - The tree computed a `children` array that no component consumed, and
    `ServerGroup` rendered only its own servers — so a subgroup created via
    "New subgroup" vanished. `ServerGroup` now renders itself recursively.
  - A parent group holding no servers directly was filtered out, hiding its
    whole subtree. A group is now kept when any descendant holds servers.
  - Nesting is no longer capped at two levels, a group whose parent was deleted
    is promoted to the root instead of becoming unreachable, and the count badge
    reports the subtree total.
- **Key auth required storing the passphrase on the server record** ([#21](https://github.com/zouwei/termex/issues/21))
  - An encrypted private key with no saved passphrase simply failed to connect.
    The backend now reports `ssh:key-passphrase-required` (and
    `ssh:key-passphrase-incorrect`) distinctly from generic auth failures, and
    the UI prompts for the passphrase and retries — on first connect, on manual
    reconnect, and on auto-reconnect. The entered passphrase is used for that
    attempt only and is never written to the database or keychain.
  - Auto-reconnect backoff now stops on a passphrase challenge or a dismissed
    prompt instead of re-opening the dialog on every attempt.
- **OSC 52 clipboard copies from Zellij/tmux/vim silently failed** ([#19](https://github.com/zouwei/termex/issues/19))
  - `navigator.clipboard.writeText` is rejected outside a user-gesture handler,
    which is exactly how OSC 52 sequences arrive, and the rejection was
    swallowed. Copies now go through a native `clipboard_write_text` command,
    with the web API kept as a fallback.
  - The base64 payload was decoded with `atob`, which is byte-oriented, so any
    non-ASCII selection (CJK, accents, emoji) was copied mangled. It is now
    decoded as UTF-8.
  - Terminal copy, the selection toolbar, and SFTP "copy path" were migrated to
    the same native path.

### Internal

- `test_recording_cleanup_expired` pinned its "recent" fixture to a literal
  `2026-04-10`, which aged past the 90-day retention window and started failing
  on 2026-07-09. The fixture is now anchored to the current time.

## [Unreleased — v0.52.0] — Gap Coverage

### Added

- **Rust backend depth for Flutter bridge**
  - `crates/termex-flutter-bridge/src/api/local_ai.rs` — wired `local_ai_start` / `local_ai_stop` to `termex_core::local_ai::LlamaServerState` with auto port allocation (15000–16000), orphan process reclamation, PID file tracking.
  - `local_ai_download_model` — HTTP Range-aware download via `termex_core::local_ai::downloader` with SHA256 verification and primary→mirror URL fallback.
  - `local_ai_cancel_download` — now sends on oneshot channel tracked in `ACTIVE_DOWNLOADS` DashMap.
  - `local_ai_auto_start_is_cancelled` / `local_ai_auto_start_reset` — atomic-flag based auto-start cancellation for Flutter's launch coroutine.
  - `termex_core::ai::provider_client` — new module with real HTTP client for Claude, OpenAI-compatible, Ollama, Gemini, and local llama-server. Supports both single-shot completion and SSE streaming.
  - `ai_verify_api_key` / `ai_test_provider_config` — real verification via minimal completion call.
  - `ai_explain_command` / `ai_diagnose_error` / `ai_nl2cmd` / `ai_autocomplete` — wired to `provider_client::complete` with proper prompt construction and context redaction.
  - `ai_send_message` / `poll_ai_chunks` / `ai_cancel_generation` — streaming generation via detached tokio task + per-conversation chunk queue polled by Dart.
  - `ai_extract_commands` — now uses `regex::Regex` for inline code extraction alongside fenced block parsing.
- **Team CRUD wiring**
  - Migration V24: `team_members` + `team_invites` tables.
  - `team_add_member` — new bridge helper for invite-accept + tests.
  - `team_get_members` / `team_remove_member` / `team_update_role` — real SQL queries, owner-protection and last-owner check enforced.
  - `team_invite_accept` — decodes + verifies signature/expiry, verifies passphrase against keychain, inserts caller as member, marks invite row as accepted.
  - `team_sync_now` — graceful no-op when no team_repo_path configured; records sync attempt timestamp; counts new pending conflicts.
- **Cross-platform disk space check**
  - `termex_core::local_ai::storage::get_available_space` — now uses the `fs2` crate for cross-platform `available_space`, walks up parent chain for missing paths.
- **FRB codegen resilience**
  - Tagged `as_str` / `from_str` / internal conversion methods with `#[flutter_rust_bridge::frb(ignore)]` so codegen no longer emits broken `RustAutoOpaqueInner<str>` bindings. Bridge now compiles cleanly against `flutter_rust_bridge = 2.12`.

### Changed

- `port_forward_find_conflict` / `port_forward_suggest_free_port` — signatures now take `String` instead of `&str` (FRB compatibility).
- Tauri storage tests updated for V24 migration count (24 total).
- Existing AI and team tests updated to assert against the new real-HTTP / real-DB behavior (see `tests/test_api_ai.rs`, `tests/test_api_team.rs`, new `tests/test_api_team_v2.rs`).

### Still pending in v0.52.0 (see [`docs/iterations/v0.52.0-gap-coverage.md`](docs/iterations/v0.52.0-gap-coverage.md))

- Version bump 0.34.0 → 0.52.0 (reserved for user-driven action per project convention).
- Release cutover: signing certificate config, first end-to-end `scripts/release.sh` dry-run, CHANGELOG promotion from `Unreleased`.
- Feature hardening: team multi-user conflict E2E test, cloud credential E2E, window state persistence lifecycle test, formal a11y walk, performance benchmark values.
- Plugin system runtime (WASM vs. scripted).

---

## [0.34.0] — 2026-02-XX

See `docs/iterations/v0.34.0-team-collaboration-v2.md`.

- Team collaboration v2: conflict resolution UI, CRDT merge of servers/snippets/proxies/recordings/cloud favorites.
- Proxy Tor binary bundled.

## [0.33.0] — Cloud Native

Cloud integration (K8s, AWS SSM, Aliyun) with shared favorites and team-aware resource permissions.

## [0.32.0] — Terminal Split Pane

## [0.31.0] — AI Assistant Evolution

## [0.30.1] — Local AI Auto-Start

Local AI engine management: top bar indicator, one-click start, AI panel progress, health check. See [`docs/iterations/v0.30.1-local-ai-auto-start.md`](docs/iterations/v0.30.1-local-ai-auto-start.md).

## [0.30.0] — Team Collaboration v1

Initial team sync via Git remotes, passphrase-encrypted workspace blobs.

## [0.29.0] — Session Recording

asciicast v2 recording + player, searchable history, auto-record toggle.

## [0.28.0] — Server Monitoring

Real-time CPU / memory / network / disk / load graphs via sshtop.

## [0.27.0] — SSH Config + Snippets

Parse & import `~/.ssh/config`; snippet library with variable interpolation and usage tracking.

## [0.26.0] — AI Smart Autocomplete

Prefix trie + AI fallback for terminal autocomplete with 4-char threshold.

## [0.25.0] — Security + Compliance

Audit log, GDPR erase-all, export/import with independent password.

## [0.24.0] — Connection Chain

## [0.23.0] — Portable Mode

## [0.22.0] — Proxy Command + Cloudflare Access

## [0.21.0] — Dynamic Forward

## [0.20.0] — Tor + Tmux + Git

## [0.19.0] — SFTP Per-Tab

## [0.18.0] — Proxy Protocols

## [0.17.0] — Server-to-Server SFTP

## [0.16.0] — Custom Keybindings

## [0.15.0] — Terminal Search

## [0.14.0] — Font Management

## [0.13.0] — SFTP Enhancement

## [0.12.0] — ProxyJump / Bastion

## [0.11.0] — Local AI (complete)

## [0.10.0] — Keychain Security

## [0.9.0] — Stable Release

## [0.8.0] — Plugin System (v1, UI only)

## [0.7.0] — Recording + Monitoring Foundations

## [0.6.0] — AI Advanced

## [0.5.0] — AI Core

## [0.4.0] — Theme + UX

## [0.3.0] — Port Forwarding

## [0.2.0] — SFTP

## [0.1.0] — MVP

Initial release: SSH password/key auth, VT100 terminal, multi-tab, SQLCipher encryption.

---

## Flutter Migration Appendix (v0.40.0–v0.51.6)

The 12 iterations v0.40.0 → v0.51.6 shipped the Flutter rewrite's foundation without cutting a user-facing release on their own version numbers. Their deliverables are rolled into **v0.52.0** (this entry).

- **v0.40.0 – v0.44.0**: Flutter shell + terminal emulator + UI design system + server management + SFTP. See status banners atop `docs/iterations/v0.40.0-flutter-foundation.md` etc.
- **v0.45.0 – v0.47.0**: AI panel, settings/team/cloud, monitor/recording.
- **v0.48.0**: Performance benchmarks (`app/benchmark/`), shortcut registry (`app/lib/shortcuts/`), window state persistence, i18n (en/zh arb).
- **v0.49.0**: Release pipeline infrastructure (`distribute_options.yaml`, platform sign scripts, auto-updater stubs, flutter-release CI).
- **v0.50.0**: Anti-AI sentinel in Rust + Dart.
- **v0.51.0 – v0.51.6**: Remediation — FRB first codegen, 71 TODO → 0, Flutter test 497/0/0.

See [`docs/iterations/v0.51.1-audit-appendix.md`](docs/iterations/v0.51.1-audit-appendix.md) for the historical audit snapshot taken at v0.51.0 kickoff.
