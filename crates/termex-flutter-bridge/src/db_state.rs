use once_cell::sync::Lazy;
use std::sync::{Arc, Mutex};
use termex_core::storage::db::Database;

static DB: Lazy<Mutex<Option<Arc<Database>>>> = Lazy::new(|| Mutex::new(None));

/// Set the global database after unlock. Replaces any existing instance.
pub fn set_db(db: Database) {
    *DB.lock().unwrap() = Some(Arc::new(db));
}

/// Returns true if a database is currently open.
pub fn is_unlocked() -> bool {
    DB.lock().unwrap().is_some()
}

/// Returns a cloned `Arc` of the currently-open database, or `None` when no
/// master password has been verified yet. Used by long-running background
/// tasks (e.g. the backup scheduler) that need to outlive a single
/// `with_db` call.
pub fn arc() -> Option<Arc<Database>> {
    DB.lock().unwrap().clone()
}

/// Run a closure with the open database, returning Err("MasterKeyNotUnlocked") if not set.
pub fn with_db<F, T>(f: F) -> Result<T, String>
where
    F: FnOnce(&Database) -> Result<T, String>,
{
    let guard = DB.lock().unwrap();
    match guard.as_ref() {
        Some(db) => f(db.as_ref()),
        None => Err("MasterKeyNotUnlocked: call verify_master_password first".into()),
    }
}

/// Test helper: initialize with an in-memory / temp-path database.
///
/// Exposed unconditionally so that integration tests in the `tests/` directory
/// (which are compiled as separate crates) can call this without a `#[cfg(test)]`
/// gating issue.
pub fn init_for_test(db: Database) {
    set_db(db);
}
