pub mod ai;
pub mod app;
pub mod audit_catalogue;
pub mod backup;
pub mod cloud;
pub mod crypto;
pub mod external_tools;
pub mod git_sync;
pub mod group;
pub mod keybindings;
pub mod local_ai;
pub mod local_fs;
pub mod local_pty;
pub mod monitor;
pub mod port_forward;
pub mod proxy;
pub mod recording;
pub mod security;
pub mod server;
pub mod settings;
pub mod sftp;
pub mod snippet;
pub mod ssh;
pub mod ssh_config;
pub mod sync;
pub mod plugin;
pub mod system;
pub mod team;
pub mod team_permissions;
pub mod theme;
pub mod update;

// ─── Mobile-only API surface ────────────────────────────────────────────────
// Compiled on all targets so a single FRB codegen run produces bindings
// usable by both desktop (termex/app) and mobile (termex-mobile/app). PC
// builds carry these modules but never call them — overhead is ~500 LoC of
// Rust code that links into the cdylib and ~2 KB of generated Dart wrappers.
pub mod mobile;
pub mod mobile_auth;
pub mod push;
pub mod team_mobile;
