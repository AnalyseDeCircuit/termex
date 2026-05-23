//! BackupScheduler — daily/weekly/monthly preset cadence driver.
//!
//! The scheduler is intentionally small: one tokio task that wakes every
//! `TICK_INTERVAL` and runs every row whose `next_run_at` is now in the
//! past. The full cron-expression case is out of scope for v0.68.0 G1; the
//! three preset frequencies cover the realistic backup automation pattern.

use std::sync::Arc;
use std::time::Duration;

use rusqlite::{params, Connection};
use time::OffsetDateTime;
use tokio::sync::Notify;
use tokio::task::JoinHandle;

use crate::keychain;

/// One minute between ticks — granular enough for daily/weekly/monthly and
/// cheap enough that CPU wake-up cost is negligible.
const TICK_INTERVAL: Duration = Duration::from_secs(60);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BackupFrequency {
    Daily,
    Weekly,
    Monthly,
}

impl BackupFrequency {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Daily => "daily",
            Self::Weekly => "weekly",
            Self::Monthly => "monthly",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "daily" => Some(Self::Daily),
            "weekly" => Some(Self::Weekly),
            "monthly" => Some(Self::Monthly),
            _ => None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct BackupScheduleRow {
    pub id: String,
    pub name: String,
    pub frequency: BackupFrequency,
    pub hour: u8,
    pub minute: u8,
    /// 0=Sun .. 6=Sat. Required when `frequency == Weekly`.
    pub weekday: Option<u8>,
    /// 1..28 — we cap at 28 to avoid month-boundary edge cases. Required
    /// when `frequency == Monthly`.
    pub day_of_month: Option<u8>,
    pub target_dir: String,
    pub password_keychain_ref: String,
    pub enabled: bool,
    pub next_run_at: OffsetDateTime,
    pub created_at: OffsetDateTime,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HistoryStatus {
    Success,
    Failed,
}

impl HistoryStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Success => "success",
            Self::Failed => "failed",
        }
    }
}

#[derive(Debug, Clone)]
pub struct BackupHistoryRow {
    pub id: String,
    pub schedule_id: Option<String>,
    pub file_path: String,
    pub size_bytes: i64,
    pub status: HistoryStatus,
    pub started_at: OffsetDateTime,
    pub completed_at: Option<OffsetDateTime>,
    pub error_msg: Option<String>,
}

/// Computes the next firing time for a schedule, relative to `from`.
///
/// Algorithm: build today's candidate (hour:minute on the right weekday /
/// day-of-month for the frequency); if that's in the past, walk forward one
/// period. Daylight-saving transitions are not modelled — the schedule
/// fires at UTC `hour`, which is the same convention the Tauri stack uses.
pub fn compute_next_run(schedule: &BackupScheduleRow, from: OffsetDateTime) -> OffsetDateTime {
    use time::{Date, Time};

    let h = schedule.hour.min(23);
    let m = schedule.minute.min(59);
    let target_time = Time::from_hms(h, m, 0).unwrap_or_else(|_| Time::MIDNIGHT);

    match schedule.frequency {
        BackupFrequency::Daily => {
            let today = from.replace_time(target_time);
            if today > from {
                today
            } else {
                today + time::Duration::days(1)
            }
        }
        BackupFrequency::Weekly => {
            let target_wd = schedule.weekday.unwrap_or(0) as i64;
            let cur_wd = from.weekday().number_days_from_sunday() as i64;
            let mut delta = (target_wd - cur_wd + 7) % 7;
            let candidate = from.replace_time(target_time) + time::Duration::days(delta);
            if candidate > from {
                candidate
            } else {
                // Same-day-of-week but past hour:minute → next week.
                if delta == 0 {
                    delta = 7;
                }
                from.replace_time(target_time) + time::Duration::days(delta.max(1))
            }
        }
        BackupFrequency::Monthly => {
            let target_dom = schedule.day_of_month.unwrap_or(1).clamp(1, 28);
            let (year, month, _day) = (from.year(), from.month(), from.day());
            let try_date = Date::from_calendar_date(year, month, target_dom);
            let candidate = match try_date {
                Ok(d) => OffsetDateTime::new_utc(d, target_time),
                Err(_) => from,
            };
            if candidate > from {
                candidate
            } else {
                // Advance to the same day next month.
                let (ny, nm) = if month as u8 == 12 {
                    (year + 1, time::Month::January)
                } else {
                    (year, month.next())
                };
                let nd = Date::from_calendar_date(ny, nm, target_dom)
                    .unwrap_or_else(|_| Date::from_calendar_date(ny, nm, 1).unwrap());
                OffsetDateTime::new_utc(nd, target_time)
            }
        }
    }
}

pub fn insert_schedule(conn: &Connection, row: &BackupScheduleRow) -> Result<(), rusqlite::Error> {
    conn.execute(
        "INSERT INTO backup_schedules
            (id, name, frequency, hour, minute, weekday, day_of_month,
             target_dir, password_keychain_ref, enabled, next_run_at, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
        params![
            row.id,
            row.name,
            row.frequency.as_str(),
            row.hour as i64,
            row.minute as i64,
            row.weekday.map(|v| v as i64),
            row.day_of_month.map(|v| v as i64),
            row.target_dir,
            row.password_keychain_ref,
            if row.enabled { 1 } else { 0 },
            row.next_run_at.to_string(),
            row.created_at.to_string(),
        ],
    )?;
    Ok(())
}

pub fn list_schedules(conn: &Connection) -> Result<Vec<BackupScheduleRow>, rusqlite::Error> {
    let mut stmt = conn.prepare(
        "SELECT id, name, frequency, hour, minute, weekday, day_of_month,
                target_dir, password_keychain_ref, enabled, next_run_at, created_at
         FROM backup_schedules
         ORDER BY created_at DESC",
    )?;
    let rows = stmt.query_map([], |r| Ok(BackupScheduleRow {
        id: r.get(0)?,
        name: r.get(1)?,
        frequency: BackupFrequency::parse(&r.get::<_, String>(2)?)
            .unwrap_or(BackupFrequency::Daily),
        hour: r.get::<_, i64>(3)? as u8,
        minute: r.get::<_, i64>(4)? as u8,
        weekday: r.get::<_, Option<i64>>(5)?.map(|v| v as u8),
        day_of_month: r.get::<_, Option<i64>>(6)?.map(|v| v as u8),
        target_dir: r.get(7)?,
        password_keychain_ref: r.get(8)?,
        enabled: r.get::<_, i64>(9)? != 0,
        next_run_at: parse_dt(&r.get::<_, String>(10)?),
        created_at: parse_dt(&r.get::<_, String>(11)?),
    }))?;
    rows.collect()
}

pub fn update_schedule(
    conn: &Connection,
    id: &str,
    name: Option<&str>,
    frequency: Option<BackupFrequency>,
    hour: Option<u8>,
    minute: Option<u8>,
    weekday: Option<Option<u8>>,
    day_of_month: Option<Option<u8>>,
    target_dir: Option<&str>,
    enabled: Option<bool>,
) -> Result<(), rusqlite::Error> {
    let row = conn.query_row(
        "SELECT name, frequency, hour, minute, weekday, day_of_month,
                target_dir, enabled
         FROM backup_schedules WHERE id = ?1",
        params![id],
        |r| {
            Ok((
                r.get::<_, String>(0)?,
                r.get::<_, String>(1)?,
                r.get::<_, i64>(2)?,
                r.get::<_, i64>(3)?,
                r.get::<_, Option<i64>>(4)?,
                r.get::<_, Option<i64>>(5)?,
                r.get::<_, String>(6)?,
                r.get::<_, i64>(7)?,
            ))
        },
    )?;

    let new_name = name.unwrap_or(&row.0).to_string();
    let new_freq = frequency
        .map(|f| f.as_str().to_string())
        .unwrap_or(row.1);
    let new_hour = hour.map(|v| v as i64).unwrap_or(row.2);
    let new_minute = minute.map(|v| v as i64).unwrap_or(row.3);
    let new_weekday = weekday
        .map(|opt| opt.map(|v| v as i64))
        .unwrap_or(row.4);
    let new_dom = day_of_month
        .map(|opt| opt.map(|v| v as i64))
        .unwrap_or(row.5);
    let new_target = target_dir.unwrap_or(&row.6).to_string();
    let new_enabled = enabled.map(|b| if b { 1i64 } else { 0 }).unwrap_or(row.7);

    // Recompute next_run_at from the updated cadence so a Friday → Sunday
    // change takes effect on the next tick.
    let temp = BackupScheduleRow {
        id: id.to_string(),
        name: new_name.clone(),
        frequency: BackupFrequency::parse(&new_freq).unwrap_or(BackupFrequency::Daily),
        hour: new_hour as u8,
        minute: new_minute as u8,
        weekday: new_weekday.map(|v| v as u8),
        day_of_month: new_dom.map(|v| v as u8),
        target_dir: new_target.clone(),
        password_keychain_ref: String::new(),
        enabled: new_enabled != 0,
        next_run_at: OffsetDateTime::now_utc(),
        created_at: OffsetDateTime::now_utc(),
    };
    let next = compute_next_run(&temp, OffsetDateTime::now_utc());

    conn.execute(
        "UPDATE backup_schedules
         SET name = ?2, frequency = ?3, hour = ?4, minute = ?5,
             weekday = ?6, day_of_month = ?7, target_dir = ?8,
             enabled = ?9, next_run_at = ?10
         WHERE id = ?1",
        params![
            id, new_name, new_freq, new_hour, new_minute, new_weekday, new_dom,
            new_target, new_enabled, next.to_string()
        ],
    )?;
    Ok(())
}

pub fn delete_schedule(conn: &Connection, id: &str) -> Result<(), rusqlite::Error> {
    conn.execute("DELETE FROM backup_schedules WHERE id = ?1", params![id])?;
    Ok(())
}

pub fn list_history(
    conn: &Connection,
    schedule_id: Option<&str>,
    limit: i64,
    offset: i64,
) -> Result<Vec<BackupHistoryRow>, rusqlite::Error> {
    let mut stmt;
    let rows: Vec<BackupHistoryRow> = if let Some(sid) = schedule_id {
        stmt = conn.prepare(
            "SELECT id, schedule_id, file_path, size_bytes, status,
                    started_at, completed_at, error_msg
             FROM backup_history
             WHERE schedule_id = ?1
             ORDER BY started_at DESC
             LIMIT ?2 OFFSET ?3",
        )?;
        stmt.query_map(params![sid, limit, offset], map_history_row)?
            .collect::<Result<_, _>>()?
    } else {
        stmt = conn.prepare(
            "SELECT id, schedule_id, file_path, size_bytes, status,
                    started_at, completed_at, error_msg
             FROM backup_history
             ORDER BY started_at DESC
             LIMIT ?1 OFFSET ?2",
        )?;
        stmt.query_map(params![limit, offset], map_history_row)?
            .collect::<Result<_, _>>()?
    };
    Ok(rows)
}

fn map_history_row(r: &rusqlite::Row<'_>) -> Result<BackupHistoryRow, rusqlite::Error> {
    Ok(BackupHistoryRow {
        id: r.get(0)?,
        schedule_id: r.get(1)?,
        file_path: r.get(2)?,
        size_bytes: r.get(3)?,
        status: match r.get::<_, String>(4)?.as_str() {
            "success" => HistoryStatus::Success,
            _ => HistoryStatus::Failed,
        },
        started_at: parse_dt(&r.get::<_, String>(5)?),
        completed_at: r
            .get::<_, Option<String>>(6)?
            .map(|s| parse_dt(&s)),
        error_msg: r.get(7)?,
    })
}

pub fn record_history(
    conn: &Connection,
    row: &BackupHistoryRow,
) -> Result<(), rusqlite::Error> {
    conn.execute(
        "INSERT INTO backup_history
            (id, schedule_id, file_path, size_bytes, status,
             started_at, completed_at, error_msg)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![
            row.id,
            row.schedule_id,
            row.file_path,
            row.size_bytes,
            row.status.as_str(),
            row.started_at.to_string(),
            row.completed_at.map(|t| t.to_string()),
            row.error_msg,
        ],
    )?;
    Ok(())
}

fn parse_dt(s: &str) -> OffsetDateTime {
    // We write timestamps via `OffsetDateTime::to_string()` — `time` 0.3's
    // Display format is round-trippable by `parse(..., &Rfc3339)` provided
    // the value has a UTC offset (`Z` or `+HH:MM`). Corrupt rows fall back
    // to `now` so the tick loop never crashes on a malformed cell.
    use time::format_description::well_known::Rfc3339;
    OffsetDateTime::parse(s, &Rfc3339).unwrap_or_else(|_| OffsetDateTime::now_utc())
}

/// Handle owned by the caller (typically the bridge crate) so the scheduler
/// task can be shut down on app exit.
pub struct BackupSchedulerHandle {
    notify: Arc<Notify>,
    task: Option<JoinHandle<()>>,
}

impl BackupSchedulerHandle {
    /// Stop the scheduler and wait for the tick task to finish. Best-effort
    /// — if the task panicked we swallow the join error since shutdown
    /// shouldn't fail because of a backup glitch.
    pub async fn shutdown(mut self) {
        self.notify.notify_one();
        if let Some(t) = self.task.take() {
            let _ = t.await;
        }
    }

    /// Nudge the tick loop to wake up immediately — used by `run_now` and
    /// `add_schedule` so a freshly added schedule fires without waiting up
    /// to a minute for the next tick.
    pub fn poke(&self) {
        self.notify.notify_one();
    }
}

/// Spawns the scheduler tick loop. The provided `runner` is called for
/// every schedule that needs to fire; it receives the schedule row plus the
/// keychain password and is expected to encrypt + write the backup file
/// then return its size. Returning `Err` causes the scheduler to log a
/// failure history row but continue running.
///
/// The bridge crate wires the runner to `backup_encrypt_to_file`; tests can
/// inject a no-op runner.
pub fn start_scheduler<F>(
    db: Arc<crate::storage::db::Database>,
    runner: F,
) -> BackupSchedulerHandle
where
    F: Fn(&BackupScheduleRow, String) -> Result<i64, String> + Send + Sync + 'static,
{
    let notify = Arc::new(Notify::new());
    let notify_clone = notify.clone();
    let runner = Arc::new(runner);

    let task = tokio::spawn(async move {
        loop {
            tokio::select! {
                _ = tokio::time::sleep(TICK_INTERVAL) => {}
                _ = notify_clone.notified() => {
                    // External nudge — either shutdown or an `add_schedule`
                    // / `run_now` poke. We re-enter the body either way;
                    // on shutdown the conn will fail or be dropped and the
                    // loop exits via the outer return.
                }
            }

            if let Err(e) = tick_once(&db, runner.clone()).await {
                log::warn!("backup scheduler tick failed: {e}");
            }
        }
    });

    BackupSchedulerHandle {
        notify,
        task: Some(task),
    }
}

async fn tick_once<F>(
    db: &Arc<crate::storage::db::Database>,
    runner: Arc<F>,
) -> Result<(), String>
where
    F: Fn(&BackupScheduleRow, String) -> Result<i64, String> + Send + Sync + 'static,
{
    let now = OffsetDateTime::now_utc();
    let due: Vec<BackupScheduleRow> = db
        .with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, frequency, hour, minute, weekday, day_of_month,
                        target_dir, password_keychain_ref, enabled, next_run_at, created_at
                 FROM backup_schedules
                 WHERE enabled = 1 AND next_run_at <= ?1",
            )?;
            let rows = stmt.query_map(params![now.to_string()], |r| Ok(BackupScheduleRow {
                id: r.get(0)?,
                name: r.get(1)?,
                frequency: BackupFrequency::parse(&r.get::<_, String>(2)?)
                    .unwrap_or(BackupFrequency::Daily),
                hour: r.get::<_, i64>(3)? as u8,
                minute: r.get::<_, i64>(4)? as u8,
                weekday: r.get::<_, Option<i64>>(5)?.map(|v| v as u8),
                day_of_month: r.get::<_, Option<i64>>(6)?.map(|v| v as u8),
                target_dir: r.get(7)?,
                password_keychain_ref: r.get(8)?,
                enabled: r.get::<_, i64>(9)? != 0,
                next_run_at: parse_dt(&r.get::<_, String>(10)?),
                created_at: parse_dt(&r.get::<_, String>(11)?),
            }))?;
            rows.collect::<Result<_, _>>()
        })
        .map_err(|e| e.to_string())?;

    for schedule in due {
        run_one(db, &schedule, runner.clone()).await;
    }
    Ok(())
}

async fn run_one<F>(
    db: &Arc<crate::storage::db::Database>,
    schedule: &BackupScheduleRow,
    runner: Arc<F>,
) where
    F: Fn(&BackupScheduleRow, String) -> Result<i64, String> + Send + Sync + 'static,
{
    let started_at = OffsetDateTime::now_utc();
    let history_id = uuid::Uuid::new_v4().to_string();
    let date_stamp = format!(
        "{:04}{:02}{:02}-{:02}{:02}",
        started_at.year(),
        started_at.month() as u8,
        started_at.day(),
        started_at.hour(),
        started_at.minute(),
    );
    let file_path = format!(
        "{}/termex-{}-{}.termex",
        schedule.target_dir.trim_end_matches('/'),
        schedule.id,
        date_stamp
    );

    let password = match keychain::get(&schedule.password_keychain_ref) {
        Ok(p) => p,
        Err(e) => {
            let _ = persist_history(
                db,
                &history_id,
                Some(&schedule.id),
                &file_path,
                0,
                HistoryStatus::Failed,
                started_at,
                Some(OffsetDateTime::now_utc()),
                Some(&format!("keychain read failed: {e}")),
            );
            advance_next_run(db, schedule);
            return;
        }
    };

    let row_clone = schedule.clone();
    let runner_clone = runner.clone();
    let result = tokio::task::spawn_blocking(move || runner_clone(&row_clone, password))
        .await
        .unwrap_or_else(|e| Err(format!("runner panic: {e}")));

    let completed_at = OffsetDateTime::now_utc();
    match result {
        Ok(size) => {
            let _ = persist_history(
                db,
                &history_id,
                Some(&schedule.id),
                &file_path,
                size,
                HistoryStatus::Success,
                started_at,
                Some(completed_at),
                None,
            );
        }
        Err(err) => {
            let _ = persist_history(
                db,
                &history_id,
                Some(&schedule.id),
                &file_path,
                0,
                HistoryStatus::Failed,
                started_at,
                Some(completed_at),
                Some(&err),
            );
        }
    }
    advance_next_run(db, schedule);
}

fn advance_next_run(db: &Arc<crate::storage::db::Database>, schedule: &BackupScheduleRow) {
    let next = compute_next_run(schedule, OffsetDateTime::now_utc());
    let _ = db.with_conn(|conn| {
        conn.execute(
            "UPDATE backup_schedules SET next_run_at = ?2 WHERE id = ?1",
            params![schedule.id, next.to_string()],
        )?;
        Ok::<(), rusqlite::Error>(())
    });
}

#[allow(clippy::too_many_arguments)]
fn persist_history(
    db: &Arc<crate::storage::db::Database>,
    id: &str,
    schedule_id: Option<&str>,
    file_path: &str,
    size_bytes: i64,
    status: HistoryStatus,
    started_at: OffsetDateTime,
    completed_at: Option<OffsetDateTime>,
    error_msg: Option<&str>,
) -> Result<(), String> {
    db.with_conn(|conn| {
        conn.execute(
            "INSERT INTO backup_history
                (id, schedule_id, file_path, size_bytes, status,
                 started_at, completed_at, error_msg)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                id,
                schedule_id,
                file_path,
                size_bytes,
                status.as_str(),
                started_at.to_string(),
                completed_at.map(|t| t.to_string()),
                error_msg,
            ],
        )?;
        Ok::<(), rusqlite::Error>(())
    })
    .map_err(|e| e.to_string())
}
