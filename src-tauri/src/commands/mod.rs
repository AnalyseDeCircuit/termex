// Tauri IPC command handlers — one submodule per domain.

pub mod audit;
pub mod config;
pub mod crypto;
pub mod port_forward;
pub mod proxy;
pub mod server;
pub mod sftp;
pub mod ssh;
pub mod settings;
pub mod ai;
pub mod plugin;
pub mod recording;
pub mod local_fs;
pub mod update;
pub mod local_ai;
pub mod fonts;
pub mod menu;
pub mod tor;
pub mod git_sync;
pub mod clipboard;
pub mod portable;
pub mod privacy;
pub mod snippet;
pub mod ssh_config;
pub mod monitor;
// Team commands depend on termex-core-private (crypto/git/permission/sync);
// only present with `--features private`.
#[cfg(feature = "private")]
pub mod team;
#[cfg(feature = "private")]
pub mod team_ext;
pub mod cloud;
