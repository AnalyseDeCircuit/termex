use crate::db_state;
use termex_core::storage::db::Database;

/// Verify the master password by attempting to open the database.
///
/// Returns `Ok(true)` on success, `Ok(false)` if the password is wrong,
/// or `Err(...)` if the database is corrupt or unreadable for another reason.
pub fn verify_master_password(password: String) -> Result<bool, String> {
    match Database::open(Some(&password)) {
        Ok(db) => {
            db_state::set_db(db);
            Ok(true)
        }
        Err(e) => {
            let msg = e.to_string();
            // SQLCipher returns "file is not a database" on wrong password
            if msg.contains("file is not a database") || msg.contains("SQLITE_NOTADB") {
                Ok(false)
            } else {
                Err(msg)
            }
        }
    }
}

/// Unlock the database with a master password.
///
/// On success the global DB singleton is set so subsequent API calls work.
pub fn unlock_database(password: String) -> Result<(), String> {
    match Database::open(Some(&password)) {
        Ok(db) => {
            db_state::set_db(db);
            Ok(())
        }
        Err(e) => Err(e.to_string()),
    }
}
