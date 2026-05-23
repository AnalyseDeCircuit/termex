//! Race-safe task ownership transitions.
//!
//! Stored as two columns the daemon adds to its `tasks` table
//! (`primary_device_id`, `ownership_changed_at`). The contention
//! point is the takeover transaction: two clients can race for the
//! same task, but the loser must learn *why* it lost so the UI can
//! re-fetch instead of looping. We use a conditional `UPDATE … WHERE
//! primary_device_id = expected` inside `BEGIN IMMEDIATE`; the row
//! count tells us whether we won.
//!
//! The schema migration for `tasks` lives in the daemon crate (it
//! owns the table); `ensure_test_schema` here builds a minimal
//! version for unit tests so the ownership logic can be exercised
//! without bringing in the daemon DB.

use rusqlite::{params, Connection, OptionalExtension};

use super::{HandoffError, TakeoverOutcome};

/// Test-only helper: builds the minimum `tasks` shape needed by the
/// queries below. Production daemons set up the table themselves and
/// just call the ownership functions.
pub fn ensure_test_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS tasks (
            id                    TEXT PRIMARY KEY,
            primary_device_id     TEXT,
            ownership_changed_at  TEXT
         );",
    )
}

/// Look up the current owner. `Ok(None)` means the row exists but
/// has no owner; `UnknownDevice` (re-used) is *not* the right error
/// for a missing task — callers fetch the task separately.
pub fn current_owner(
    conn: &Connection,
    task_id: &str,
) -> Result<Option<String>, HandoffError> {
    let row = conn
        .query_row(
            "SELECT primary_device_id FROM tasks WHERE id = ?1",
            params![task_id],
            |r| r.get::<_, Option<String>>(0),
        )
        .optional()?;
    Ok(row.flatten())
}

/// Attempt to take ownership of `task_id` for `new_owner`.
///
/// `expected_previous_owner`:
///  - `Some(id)` → strict swap: succeeds only if the current owner
///    matches; used when the UI already knows who owns the task and
///    wants to detect concurrent steals.
///  - `None` → claim if currently unowned or matches the new owner
///    (idempotent re-claim).
///
/// Either way the daemon serializes through `BEGIN IMMEDIATE` so the
/// SQLite-level write lock blocks concurrent takeover attempts;
/// after we commit, racers re-run the SELECT and see the new owner.
pub fn try_takeover(
    conn: &mut Connection,
    task_id: &str,
    new_owner: &str,
    expected_previous_owner: Option<&str>,
    now_rfc3339: &str,
) -> Result<TakeoverOutcome, HandoffError> {
    let tx = conn.transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)?;
    let current: Option<String> = tx
        .query_row(
            "SELECT primary_device_id FROM tasks WHERE id = ?1",
            params![task_id],
            |r| r.get::<_, Option<String>>(0),
        )
        .optional()?
        .flatten();

    let allowed = match expected_previous_owner {
        Some(expected) => current.as_deref() == Some(expected),
        None => match current.as_deref() {
            None => true,
            Some(owner) => owner == new_owner,
        },
    };

    if !allowed {
        // Don't write; let the racer learn the actual owner.
        return Ok(TakeoverOutcome::RaceLost {
            actual_owner_id: current,
        });
    }

    tx.execute(
        "UPDATE tasks
            SET primary_device_id    = ?2,
                ownership_changed_at = ?3
          WHERE id = ?1",
        params![task_id, new_owner, now_rfc3339],
    )?;
    tx.commit()?;
    Ok(TakeoverOutcome::Won {
        previous_owner_id: current,
    })
}

/// Release ownership unconditionally — used by the "log out this
/// device" flow so abandoned tasks don't keep pinging push.
pub fn release(
    conn: &Connection,
    task_id: &str,
    now_rfc3339: &str,
) -> Result<(), HandoffError> {
    conn.execute(
        "UPDATE tasks
            SET primary_device_id    = NULL,
                ownership_changed_at = ?2
          WHERE id = ?1",
        params![task_id, now_rfc3339],
    )?;
    Ok(())
}
