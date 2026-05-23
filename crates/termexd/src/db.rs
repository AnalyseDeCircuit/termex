//! SQLite-backed daemon-side task store (`~/.termex/tasks.db`).
//!
//! Independent of the client's `termex.db` migration framework — the
//! daemon ships its own schema_version meta table (v0.71.2 will add
//! `events_log`; v0.71.1 will add `task_artifacts`; v0.74.2 will add
//! `devices` + ownership columns).
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.5.

use std::path::Path;

use rusqlite::{params, Connection, OptionalExtension};

use termex_core::task::{AiCliKind, Task, TaskStatus};

use crate::error::DaemonError;

const DAEMON_DB_SCHEMA_VERSION: i32 = 1;

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn open(path: &Path) -> Result<Self, DaemonError> {
        let conn = Connection::open(path)?;
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        let db = Self { conn };
        db.ensure_schema()?;
        Ok(db)
    }

    /// In-memory database for unit tests.
    pub fn in_memory() -> Result<Self, DaemonError> {
        let conn = Connection::open_in_memory()?;
        let db = Self { conn };
        db.ensure_schema()?;
        Ok(db)
    }

    fn ensure_schema(&self) -> Result<(), DaemonError> {
        self.conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS meta (
                 key   TEXT PRIMARY KEY,
                 value TEXT
             );
             CREATE TABLE IF NOT EXISTS tasks (
                 id               TEXT PRIMARY KEY,
                 ai_cli_kind      TEXT NOT NULL,
                 prompt           TEXT NOT NULL,
                 workdir          TEXT,
                 status           TEXT NOT NULL,
                 started_at       TEXT NOT NULL,
                 ended_at         TEXT,
                 exit_code        INTEGER,
                 idle_timeout_sec INTEGER NOT NULL DEFAULT 30,
                 output_tail      TEXT,
                 error            TEXT
             );
             CREATE INDEX IF NOT EXISTS idx_tasks_status  ON tasks(status);
             CREATE INDEX IF NOT EXISTS idx_tasks_started ON tasks(started_at);",
        )?;

        self.conn.execute(
            "INSERT OR REPLACE INTO meta (key, value) VALUES ('schema_version', ?1)",
            params![DAEMON_DB_SCHEMA_VERSION.to_string()],
        )?;
        Ok(())
    }

    pub fn insert_task(&self, task: &Task) -> Result<(), DaemonError> {
        self.conn.execute(
            "INSERT INTO tasks
                 (id, ai_cli_kind, prompt, workdir, status, started_at,
                  ended_at, exit_code, idle_timeout_sec, output_tail, error)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
            params![
                task.id,
                ai_cli_kind_as_str(task.ai_cli_kind),
                task.prompt,
                task.workdir,
                status_as_str(task.status),
                task.started_at,
                task.ended_at,
                task.exit_code,
                task.idle_timeout_sec,
                task.output_tail,
                task.error,
            ],
        )?;
        Ok(())
    }

    pub fn get_task(&self, id: &str) -> Result<Option<Task>, DaemonError> {
        let row = self
            .conn
            .query_row(
                "SELECT id, ai_cli_kind, prompt, workdir, status, started_at,
                        ended_at, exit_code, idle_timeout_sec, output_tail, error
                 FROM tasks WHERE id = ?1",
                params![id],
                map_row_to_task,
            )
            .optional()?;
        Ok(row)
    }

    pub fn list_tasks(&self, status_filter: Option<TaskStatus>) -> Result<Vec<Task>, DaemonError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, ai_cli_kind, prompt, workdir, status, started_at,
                    ended_at, exit_code, idle_timeout_sec, output_tail, error
             FROM tasks
             WHERE (?1 IS NULL OR status = ?1)
             ORDER BY started_at DESC",
        )?;
        let status_str = status_filter.map(status_as_str);
        let rows = stmt.query_map(params![status_str], map_row_to_task)?;
        let mut tasks = Vec::new();
        for r in rows {
            tasks.push(r?);
        }
        Ok(tasks)
    }

    pub fn update_status(
        &self,
        id: &str,
        status: TaskStatus,
        ended_at: Option<&str>,
        exit_code: Option<i32>,
        error: Option<&str>,
    ) -> Result<(), DaemonError> {
        let affected = self.conn.execute(
            "UPDATE tasks
                SET status = ?1, ended_at = ?2, exit_code = ?3, error = ?4
              WHERE id = ?5",
            params![status_as_str(status), ended_at, exit_code, error, id],
        )?;
        if affected == 0 {
            return Err(DaemonError::TaskNotFound(id.to_string()));
        }
        Ok(())
    }

    /// Replace the rolling `output_tail` for a task (called by the
    /// supervisor when the PTY EOFs).
    pub fn update_output_tail(&self, id: &str, tail: &str) -> Result<(), DaemonError> {
        self.conn.execute(
            "UPDATE tasks SET output_tail = ?1 WHERE id = ?2",
            params![tail, id],
        )?;
        Ok(())
    }

    pub fn schema_version(&self) -> Result<i32, DaemonError> {
        let v: String = self
            .conn
            .query_row(
                "SELECT value FROM meta WHERE key = 'schema_version'",
                [],
                |r| r.get(0),
            )
            .optional()?
            .unwrap_or_else(|| "0".to_string());
        Ok(v.parse().unwrap_or(0))
    }
}

fn map_row_to_task(row: &rusqlite::Row) -> rusqlite::Result<Task> {
    Ok(Task {
        id: row.get(0)?,
        ai_cli_kind: ai_cli_kind_from_str(&row.get::<_, String>(1)?),
        prompt: row.get(2)?,
        workdir: row.get(3)?,
        status: status_from_str(&row.get::<_, String>(4)?),
        started_at: row.get(5)?,
        ended_at: row.get(6)?,
        exit_code: row.get(7)?,
        idle_timeout_sec: row.get::<_, i64>(8)? as u32,
        output_tail: row.get(9)?,
        error: row.get(10)?,
    })
}

fn ai_cli_kind_as_str(kind: AiCliKind) -> &'static str {
    match kind {
        AiCliKind::ClaudeCode => "claude_code",
        AiCliKind::Codex => "codex",
        AiCliKind::Aider => "aider",
        AiCliKind::Generic => "generic",
    }
}

fn ai_cli_kind_from_str(s: &str) -> AiCliKind {
    match s {
        "claude_code" => AiCliKind::ClaudeCode,
        "codex" => AiCliKind::Codex,
        "aider" => AiCliKind::Aider,
        _ => AiCliKind::Generic,
    }
}

fn status_as_str(s: TaskStatus) -> &'static str {
    match s {
        TaskStatus::Pending => "pending",
        TaskStatus::PendingConfirmation => "pending_confirmation",
        TaskStatus::Running => "running",
        TaskStatus::Succeeded => "succeeded",
        TaskStatus::Failed => "failed",
        TaskStatus::Cancelled => "cancelled",
    }
}

fn status_from_str(s: &str) -> TaskStatus {
    match s {
        "pending_confirmation" => TaskStatus::PendingConfirmation,
        "running" => TaskStatus::Running,
        "succeeded" => TaskStatus::Succeeded,
        "failed" => TaskStatus::Failed,
        "cancelled" => TaskStatus::Cancelled,
        _ => TaskStatus::Pending,
    }
}
