//! `termexd` — the Termex remote daemon.
//!
//! Single-binary, single-user Rust daemon that owns AI long-running
//! task state on the remote machine. Mobile and desktop clients
//! connect over a WebSocket carried inside an SSH tunnel.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` for the full
//! design.

use std::path::PathBuf;

use anyhow::Context;
use clap::Parser;
use tracing::info;
use tracing_subscriber::EnvFilter;

mod auth;
mod db;
mod error;
mod event_bus;
mod handler;
mod server;

use crate::db::Database;
use crate::event_bus::EventBus;
use crate::handler::HandlerCtx;

/// CLI for the termexd binary.
#[derive(Parser, Debug)]
#[command(
    name = "termexd",
    version,
    about = "Termex remote daemon — owns task state on the remote machine"
)]
struct Cli {
    /// Address to bind the WebSocket server.
    ///
    /// Defaults to `127.0.0.1:7821` — clients reach the daemon
    /// through an SSH tunnel set up by `daemon_connect_via_ssh`.
    /// Binding to a public address is not recommended; v0.71.2 will
    /// add an explicit `--tls` flag for that use case.
    #[arg(long, default_value = "127.0.0.1:7821")]
    listen: String,

    /// Optional override for the data directory (token, tasks.db).
    /// Defaults to `~/.termex` under the daemon owner's home.
    #[arg(long)]
    data_dir: Option<PathBuf>,

    /// Log level filter (`error`, `warn`, `info`, `debug`, `trace`).
    /// Honoured by `tracing`; can also be set via `RUST_LOG`.
    #[arg(long, default_value = "info")]
    log_level: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // Initialize tracing. RUST_LOG wins if set; otherwise use --log-level.
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(format!("termexd={}", cli.log_level)));
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(true)
        .init();

    let termex_home = cli
        .data_dir
        .clone()
        .or_else(|| dirs::home_dir().map(|h| h.join(".termex")))
        .context("could not resolve home directory; pass --data-dir")?;

    info!(
        listen = %cli.listen,
        data_dir = %termex_home.display(),
        "starting termexd"
    );

    // Initialize auth token + DB. The full WS server wires up in a
    // follow-up commit; this milestone bootstraps the persistent
    // state.
    let token = auth::load_or_create_token(&termex_home)?;
    let db = Database::open(&termex_home.join("tasks.db"))?;
    let bus = EventBus::new();
    let ctx = HandlerCtx::new(db, bus);

    println!();
    println!("termexd is running.");
    println!();
    println!(
        "Token (also saved to {}/daemon.token, mode 0600):",
        termex_home.display()
    );
    println!("    {}", token);
    println!();
    println!(
        "Connect from your Termex client by establishing an SSH tunnel \
         (`-L <port>:127.0.0.1:7821`) and pointing the client at \
         ws://127.0.0.1:<port>/v1/stream with the token above."
    );
    println!();

    let listen = cli.listen.clone();
    let server_handle = tokio::spawn(async move { server::run(&listen, token, ctx).await });

    tokio::select! {
        _ = tokio::signal::ctrl_c() => {
            info!("ctrl-c received, shutting down");
        }
        res = server_handle => match res {
            Ok(Ok(())) => info!("server returned cleanly"),
            Ok(Err(e)) => return Err(e),
            Err(e) => return Err(anyhow::anyhow!("server task panicked: {e}")),
        },
    }
    Ok(())
}
