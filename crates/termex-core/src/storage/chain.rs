//! Connection chain CRUD operations.
//!
//! Each server can have an ordered chain of hops (SSH bastions and network proxies).
//! Hops with `phase = "pre"` come before the target; `phase = "post"` come after.

use super::db::Database;
use super::models::{ChainHop, ChainHopInput};

/// Lists all chain hops for a server, ordered by position.
pub fn list(db: &Database, server_id: &str) -> Result<Vec<ChainHop>, super::DbError> {
    db.with_conn(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, server_id, position, hop_type, hop_id, phase, created_at
             FROM connection_chain
             WHERE server_id = ?1
             ORDER BY position",
        )?;
        let rows = stmt
            .query_map(rusqlite::params![server_id], |row| {
                Ok(ChainHop {
                    id: row.get(0)?,
                    server_id: row.get(1)?,
                    position: row.get(2)?,
                    hop_type: row.get(3)?,
                    hop_id: row.get(4)?,
                    phase: row.get(5)?,
                    created_at: row.get(6)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(rows)
    })
}

/// Replaces the entire chain for a server (DELETE + INSERT).
/// Assigns position values in the order provided.
pub fn save(
    db: &Database,
    server_id: &str,
    hops: &[ChainHopInput],
) -> Result<(), super::DbError> {
    db.with_conn(|conn| {
        // Delete existing chain
        conn.execute(
            "DELETE FROM connection_chain WHERE server_id = ?1",
            rusqlite::params![server_id],
        )?;

        // Insert new hops with sequential positions
        let now = time::OffsetDateTime::now_utc().to_string();
        let mut stmt = conn.prepare(
            "INSERT INTO connection_chain (id, server_id, position, hop_type, hop_id, phase, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        )?;

        for (i, hop) in hops.iter().enumerate() {
            let id = uuid::Uuid::new_v4().to_string();
            stmt.execute(rusqlite::params![
                id,
                server_id,
                i as i32,
                hop.hop_type,
                hop.hop_id,
                hop.phase,
                now,
            ])?;
        }

        Ok(())
    })
}

/// Deletes the entire chain for a server.
pub fn delete(db: &Database, server_id: &str) -> Result<(), super::DbError> {
    db.with_conn(|conn| {
        conn.execute(
            "DELETE FROM connection_chain WHERE server_id = ?1",
            rusqlite::params![server_id],
        )?;
        Ok(())
    })
}
