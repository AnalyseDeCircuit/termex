//! PTY-based task supervisor.
//!
//! Spawns AI CLI subprocesses on an allocated PTY, captures their
//! stdout/stderr as a single combined stream (PTY semantics), pushes
//! each chunk to the event bus, watches for child exit, and updates
//! the task status in the DB.
//!
//! Cancel sends `Ctrl-C` (\x03) into the PTY input; `sigterm` calls
//! the child's `kill()` method for a slightly harder shutdown.
//! `sigkill` is the nuclear option (10s grace then force).
//!
//! v0.71.0 milestone scope: stdout-only completion (idle + exit). MCP
//! adapter (v0.71.1) and stdout AI CLI adapters (v0.72.1) plug in
//! later as `CompletionDetector` impls.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.4.

use std::collections::HashMap;
use std::io::Read;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use portable_pty::{native_pty_system, CommandBuilder, MasterPty, PtySize};
use tokio::sync::Mutex;
use tracing::{debug, info, warn};

use termex_core::daemon::{OutputStream, ServerMessage};
use termex_core::task::{AiCliKind, TaskStatus};

use crate::db::Database;
use crate::error::DaemonError;
use crate::event_bus::EventBus;

const TAIL_BYTES: usize = 8 * 1024;
const CANCEL_GRACE_MS: u64 = 10_000;

/// One PTY-supervised task. Held by the [`TaskSupervisor`] until the
/// child exits (the waiter removes the entry) or is cancelled.
///
/// The reader/waiter blocking threads own themselves and exit
/// naturally when the master fd EOFs (i.e. child exits). We do NOT
/// share the child handle here — the waiter takes ownership of it
/// (so it can block on `wait()` without holding a mutex anyone else
/// might need). For cancel-by-signal we keep the OS pid and use
/// `libc::kill` directly, avoiding lock contention with the waiter.
struct ActiveTask {
    /// Used to write Ctrl-C into the PTY for sigint cancellation.
    master: Arc<Mutex<Box<dyn MasterPty + Send>>>,
    /// OS pid of the subprocess (None if the platform reported no pid).
    process_id: Option<u32>,
}

/// Supervises the set of running task subprocesses.
#[derive(Clone)]
pub struct TaskSupervisor {
    inner: Arc<SupervisorInner>,
}

struct SupervisorInner {
    db: Arc<Mutex<Database>>,
    bus: EventBus,
    active: Mutex<HashMap<String, ActiveTask>>,
}

impl TaskSupervisor {
    pub fn new(db: Arc<Mutex<Database>>, bus: EventBus) -> Self {
        Self {
            inner: Arc::new(SupervisorInner {
                db,
                bus,
                active: Mutex::new(HashMap::new()),
            }),
        }
    }

    /// Spawn the AI CLI for the given task. The Task row is assumed
    /// to already be in the DB with status = Running; this method
    /// only kicks off the subprocess + background reader/waiter.
    ///
    /// `idle_timeout_sec` is currently informational only — v0.71.1
    /// idle detector will consume it via the CompletionDetector
    /// trait.
    pub async fn spawn(
        &self,
        task_id: &str,
        ai_cli: AiCliKind,
        prompt: &str,
        workdir: Option<&str>,
    ) -> Result<(), DaemonError> {
        let mut cmd = build_command(ai_cli, prompt);
        if let Some(dir) = workdir {
            cmd.cwd(dir);
        }

        let pty_system = native_pty_system();
        let pair = pty_system
            .openpty(PtySize {
                rows: 24,
                cols: 80,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| DaemonError::PtySpawn(format!("openpty: {e}")))?;

        let child = pair
            .slave
            .spawn_command(cmd)
            .map_err(|e| DaemonError::PtySpawn(format!("spawn: {e}")))?;

        // Slave fd is owned by the child now; drop our handle so the
        // master sees EOF when the child exits.
        drop(pair.slave);

        let process_id = child.process_id();
        let master = Arc::new(Mutex::new(pair.master));

        let started_ms = now_ms();
        let task_id_owned = task_id.to_string();

        // Background reader: pulls chunks off the master, broadcasts
        // each to the event bus, and updates the rolling output_tail.
        let bus_for_reader = self.inner.bus.clone();
        let db_for_reader = self.inner.db.clone();
        let task_id_for_reader = task_id_owned.clone();
        let master_for_reader = master.clone();
        let rt = tokio::runtime::Handle::current();
        let rt_for_reader = rt.clone();
        std::thread::spawn(move || {
            run_reader(
                task_id_for_reader,
                master_for_reader,
                bus_for_reader,
                db_for_reader,
                rt_for_reader,
            );
        });

        // Background waiter: takes ownership of the child and blocks
        // on wait(). No lock — cancel uses the pid directly via
        // libc::kill so the waiter never has to release anything.
        let bus_for_waiter = self.inner.bus.clone();
        let db_for_waiter = self.inner.db.clone();
        let task_id_for_waiter = task_id_owned.clone();
        let active_for_waiter = self.inner.clone();
        let rt_for_waiter = rt.clone();
        std::thread::spawn(move || {
            run_waiter(
                task_id_for_waiter,
                child,
                bus_for_waiter,
                db_for_waiter,
                active_for_waiter,
                started_ms,
                rt_for_waiter,
            );
        });

        let active = ActiveTask { master, process_id };
        self.inner
            .active
            .lock()
            .await
            .insert(task_id_owned.clone(), active);

        info!(task = %task_id, ai_cli = ?ai_cli, "task spawned");
        Ok(())
    }

    /// Cancel a running task. Sends Ctrl-C through the PTY for sigint;
    /// uses `libc::kill(pid, SIGTERM|SIGKILL)` for the harder signals.
    /// Doesn't wait for the child to exit — the waiter thread will
    /// observe the exit and broadcast the terminal status.
    pub async fn cancel(&self, task_id: &str, signal: CancelKind) -> Result<(), DaemonError> {
        let mut active = self.inner.active.lock().await;
        let task = active
            .get_mut(task_id)
            .ok_or_else(|| DaemonError::TaskNotFound(task_id.into()))?;
        match signal {
            CancelKind::Sigint => {
                let master = task.master.clone();
                tokio::task::spawn_blocking(move || {
                    let master_guard = master.blocking_lock();
                    if let Ok(mut writer) = master_guard.take_writer() {
                        use std::io::Write;
                        let _ = writer.write_all(b"\x03");
                    }
                })
                .await
                .map_err(|e| DaemonError::Internal(format!("cancel join: {e}")))?;
            }
            CancelKind::Sigterm | CancelKind::Sigkill => {
                let Some(pid) = task.process_id else {
                    return Err(DaemonError::Internal(
                        "no pid available for hard cancel".into(),
                    ));
                };
                let sig = match signal {
                    CancelKind::Sigterm => libc::SIGTERM,
                    CancelKind::Sigkill => libc::SIGKILL,
                    _ => unreachable!(),
                };
                // Safety: signalling another process via its pid is
                // a standard Unix operation; libc::kill is safe so
                // long as `pid` is a valid i32 (process_id() returns
                // u32 on success).
                let rc = unsafe { libc::kill(pid as libc::pid_t, sig) };
                if rc != 0 {
                    let err = std::io::Error::last_os_error();
                    // ESRCH (process already gone) is a benign race:
                    // the waiter is about to clean up.
                    if err.raw_os_error() != Some(libc::ESRCH) {
                        return Err(DaemonError::Internal(format!("kill failed: {err}")));
                    }
                }
            }
        }
        let _ = CANCEL_GRACE_MS;
        Ok(())
    }

    /// Number of currently-running subprocesses (test/metrics helper).
    pub async fn active_count(&self) -> usize {
        self.inner.active.lock().await.len()
    }
}

#[derive(Debug, Clone, Copy)]
pub enum CancelKind {
    Sigint,
    Sigterm,
    #[allow(dead_code)]
    Sigkill,
}

/// Compose the shell `Command` for a given (kind, prompt). MCP-aware
/// flags land in v0.71.1; here we pass the prompt as a positional arg
/// (or `-c` for generic bash).
fn build_command(kind: AiCliKind, prompt: &str) -> CommandBuilder {
    let mut cmd = match kind {
        AiCliKind::ClaudeCode => {
            let mut c = CommandBuilder::new(kind.default_command());
            c.arg("-p");
            c.arg(prompt);
            c
        }
        AiCliKind::Codex => {
            let mut c = CommandBuilder::new(kind.default_command());
            c.arg("exec");
            c.arg(prompt);
            c
        }
        AiCliKind::Aider => {
            let mut c = CommandBuilder::new(kind.default_command());
            c.arg("--message");
            c.arg(prompt);
            c
        }
        AiCliKind::Generic => {
            let mut c = CommandBuilder::new(kind.default_command());
            c.arg("-c");
            c.arg(prompt);
            c
        }
    };
    // Inherit PATH but nothing else; conservative env defaults.
    if let Ok(path) = std::env::var("PATH") {
        cmd.env("PATH", path);
    }
    cmd
}

/// Blocking reader loop. Runs on a dedicated thread so we can call
/// the synchronous `Read::read` on the master fd without starving the
/// tokio runtime.
fn run_reader(
    task_id: String,
    master: Arc<Mutex<Box<dyn MasterPty + Send>>>,
    bus: EventBus,
    db: Arc<Mutex<Database>>,
    rt: tokio::runtime::Handle,
) {
    let mut reader = match master.blocking_lock().try_clone_reader() {
        Ok(r) => r,
        Err(e) => {
            warn!(task = %task_id, error = %e, "clone_reader failed");
            return;
        }
    };
    let mut buf = vec![0u8; 4096];
    let mut tail = String::with_capacity(TAIL_BYTES);

    loop {
        match reader.read(&mut buf) {
            Ok(0) => {
                debug!(task = %task_id, "pty EOF");
                break;
            }
            Ok(n) => {
                let chunk = String::from_utf8_lossy(&buf[..n]).into_owned();
                // Append to rolling tail, truncating from the front
                // to keep at most TAIL_BYTES.
                tail.push_str(&chunk);
                if tail.len() > TAIL_BYTES {
                    let drop_n = tail.len() - TAIL_BYTES;
                    tail.drain(..drop_n);
                }
                // Broadcast event (with monotonic seq).
                let seq = bus.next_seq();
                let msg = ServerMessage::TaskOutput {
                    task_id: task_id.clone(),
                    stream: OutputStream::Stdout,
                    data: chunk,
                    seq,
                    ts_ms: now_ms(),
                };
                let bus = bus.clone();
                let task_id_clone = task_id.clone();
                // Fire-and-forget broadcast on the tokio runtime.
                rt.spawn(async move {
                    bus.broadcast(&task_id_clone, msg).await;
                });
            }
            Err(e) => {
                debug!(task = %task_id, error = %e, "pty read error");
                break;
            }
        }
    }

    // Persist the final tail to DB.
    let db_clone = db.clone();
    let task_id_clone = task_id.clone();
    let tail_owned = tail;
    rt.spawn(async move {
        if let Err(e) = update_tail(db_clone, &task_id_clone, &tail_owned).await {
            warn!(task = %task_id_clone, error = %e, "update tail failed");
        }
    });
}

/// Blocking waiter loop. Waits for child exit and emits the terminal
/// status event. Removes the task from the active map.
///
/// Takes the child by value so no mutex stays held during the
/// indefinite `wait()` — that's critical for cancellation to remain
/// responsive (see `cancel` which signals via libc::kill, not the
/// child handle).
fn run_waiter(
    task_id: String,
    mut child: Box<dyn portable_pty::Child + Send + Sync>,
    bus: EventBus,
    db: Arc<Mutex<Database>>,
    sup: Arc<SupervisorInner>,
    started_ms: u64,
    rt: tokio::runtime::Handle,
) {
    let exit_status = child.wait();

    let (final_status, exit_code) = match exit_status {
        Ok(s) if s.success() => (TaskStatus::Succeeded, s.exit_code() as i32),
        Ok(s) => (TaskStatus::Failed, s.exit_code() as i32),
        Err(_) => (TaskStatus::Failed, -1),
    };

    let duration_ms = now_ms().saturating_sub(started_ms);

    info!(
        task = %task_id, status = ?final_status, exit_code, duration_ms,
        "task completed"
    );

    let task_id_for_async = task_id.clone();
    let bus_for_async = bus.clone();
    let db_for_async = db.clone();
    let sup_for_async = sup.clone();
    rt.spawn(async move {
        // Update DB (db method is synchronous; called inside async
        // block to hold the mutex briefly).
        if let Err(e) = db_for_async.lock().await.update_status(
            &task_id_for_async,
            final_status,
            Some(&now_rfc3339()),
            Some(exit_code),
            None,
        ) {
            warn!(task = %task_id_for_async, error = %e, "db update_status failed");
        }
        // Broadcast terminal status
        bus_for_async
            .broadcast(
                &task_id_for_async,
                ServerMessage::TaskStatus {
                    task_id: task_id_for_async.clone(),
                    status: final_status,
                    exit_code: Some(exit_code),
                    duration_ms: Some(duration_ms),
                    ts_ms: now_ms(),
                },
            )
            .await;
        // Drop from active map
        sup_for_async.active.lock().await.remove(&task_id_for_async);
    });
}

async fn update_tail(
    db: Arc<Mutex<Database>>,
    task_id: &str,
    tail: &str,
) -> Result<(), DaemonError> {
    db.lock().await.update_output_tail(task_id, tail)
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

fn now_rfc3339() -> String {
    chrono::Utc::now().to_rfc3339()
}

