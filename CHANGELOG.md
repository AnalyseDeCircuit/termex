# Changelog

All notable changes to Termex are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased — v0.69.0] — Restructure Stabilization + Tauri Retirement Announcement

### Deprecated

- 🪦 **Tauri/Vue desktop stack enters formal retirement.** A 4-phase plan over the next 24 months drives the legacy stack to physical removal at v0.80:
  - **v0.69** (this release) — Deprecation announcement: in-app banner + MIGRATION.md chapter
  - **v0.70** — Default installs switch to Flutter; AppCast critical update nudges existing Tauri users
  - **v0.75** — CI stops building Tauri release artifacts
  - **v0.80** — `src-tauri/` and `src/` (Vue) directories physically deleted
- New feature development happens exclusively in the Flutter stack (`packages/termex_shared/` + `app/` + `termex-mobile/`). The Tauri stack accepts critical security PRs only.

### Added

- `packages/termex_shared/lib/system/tauri_retirement_banner.dart` — in-app deprecation widget (`TauriRetirementBanner` inline + `showTauriRetirementDialog` modal). Banner is dismissible via SharedPreferences `termex.tauri_retire_dismissed` so it appears at most once per install.
- `docs/MIGRATION.md` — new chapter "v0.69 起：从 Tauri 桌面切换到 Flutter 桌面" with 4-phase timeline table, data-compatibility matrix (all 5 categories share zero-migration), known behavior differences, and rollback path to stable-legacy channel.
- `docs/iterations/v0.70.0-pc-tauri-retirement.md` — full retirement plan with phase deliverables, risk/mitigation matrix, and 5 user-confirmable decision points.
- `docs/iterations/v0.69.0-pc-restructure-stabilization.md` — restructure stabilization record covering the desktop/mobile package split, build-blocker fix runbook, and i18n batch survival audit.

### Changed

- `README.md` top banner — updated from "dual-stack migration period" to explicit retirement announcement with link to MIGRATION.md §v0.69.
- `src-tauri/README.md` + `src/README.md` — retirement banners promoted from "Deprecated" to "🪦 退役进行中 (4 阶段 → v0.80)" with phase timeline inline.
- `docs/architecture.md` — top-level retirement banner; "一句话定位" updated to "Tauri/Vue (老栈，退役中) 与 Flutter (新栈，生产主推)".
- `CLAUDE.md` Repository state — updated to reflect v0.68.0 functional parity completion; new explicit "for new feature development, write Flutter only" guidance.
- Repository structure split into three top-level packages:
  - `app/` — desktop PC shell only
  - `termex-mobile/app/` — iOS/Android shell (new)
  - `packages/termex_shared/` — cross-platform shared business logic and widgets
- `flutter analyze` baseline restored to 0 errors after structural cleanup (was 201 pre-restructure).

### Fixed

- Stabilized 14 broken cross-package imports in `packages/termex_shared/lib/widgets/*.dart` (`package:termex/design/tokens.dart` → `package:termex_shared/design/tokens.dart`).
- Migrated entire `features/team/` directory (20 files) from `app/lib/` to `packages/termex_shared/lib/features/team/` (subsequently relocated again during the desktop/mobile split — see v0.69 restructure doc §6).
- Restored macOS release build (was failing at Dart kernel snapshot with missing `MonitorPanel` + `showTeamPassphraseDialog` references after the second-wave restructure deleted those modules). Minimal stubs in `tab_workspace.dart` and `team_tab.dart` keep the build green until the team/cloud/monitor features land in their final package locations.
- `crates/termex-core/src/lib.rs` — added missing `pub mod sync;` registration that was blocking aarch64-apple-darwin Cargo target builds.
- `about_tab_test.dart` — added `localizationsDelegates` + `Locale('zh')` to test `MaterialApp` so post-i18n migration assertions resolve correctly; updated `find.text('已是最新版本')` to `find.textContaining(...)` to match the `updateUpToDate` ARB value (`'已是最新版本！'` with punctuation).

### Internationalization (i18n)

- ARB key set grew from 804 → **997 keys** (zh + en, +193 keys this iteration).
- Eight high-impact widget files completed full i18n migration with `AppLocalizations.of(context)`:
  - `about_tab.dart` (21 strings → 0)
  - `settings_page.dart` (29 → 0, including `kSettingsIndex` const list → `buildSettingsIndex(l)` builder)
  - `backup_tab.dart` (20 → 0)
  - `privacy_policy_dialog.dart` (30 → 0)
  - `proxies_tab.dart` (22 → 0)
  - `git_sync_panel.dart` (20 → 0)
  - `file_list.dart` (19 → 0)
- One file (`cloud_panel.dart`, 22 strings) was lost in the second-wave restructure and will be re-migrated when the cloud panel reappears in its new package location.

---

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
