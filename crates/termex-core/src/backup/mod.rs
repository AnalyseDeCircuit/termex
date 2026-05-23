//! Backup scheduling and history (v0.68.0 G1).
//!
//! The scheduler ticks once per minute, polls `backup_schedules` for entries
//! whose `next_run_at <= now AND enabled = 1`, fires the backup, then
//! advances `next_run_at` by one period. Each attempt — manual or scheduled
//! — appends to `backup_history`. To keep the dependency surface small we
//! support only the three preset frequencies the Flutter UI exposes; full
//! cron parsing is left for a future iteration.

pub mod scheduler;

pub use scheduler::{
    BackupFrequency, BackupHistoryRow, BackupScheduleRow, BackupSchedulerHandle,
    HistoryStatus, start_scheduler,
};
