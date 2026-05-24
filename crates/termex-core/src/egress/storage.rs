//! SQLite-backed CRUD for [`EgressProfile`].
//!
//! Schema is owned by the client `termex.db` migration framework
//! (the v0.74.0 design assigns migration #28 — but the existing
//! migration runner enforces a single source of truth, so this
//! module exposes both an `ensure_schema_in_memory` helper for
//! tests and live SQL queries that go through whatever connection
//! the caller hands us).

use rusqlite::{params, Connection, OptionalExtension};

use super::{EgressProfile, EgressProfileSummary, HopRef};

const SCHEMA_SQL: &str = r#"
CREATE TABLE IF NOT EXISTS egress_profiles (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    chain_hops_json TEXT NOT NULL DEFAULT '[]',
    proxy_id        TEXT,
    owner_device    TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_egress_profiles_name
    ON egress_profiles(name);
"#;

/// Test-only — applies the schema on a fresh in-memory connection.
/// Production callers go through the central migrations runner.
pub fn ensure_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_SQL)
}

#[derive(Debug, thiserror::Error)]
pub enum EgressError {
    #[error("profile not found: {0}")]
    NotFound(String),
    #[error("duplicate name within owner_device: {0}")]
    DuplicateName(String),
    #[error("sql: {0}")]
    Sql(#[from] rusqlite::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
}

pub fn list(conn: &Connection) -> Result<Vec<EgressProfile>, EgressError> {
    let mut stmt = conn.prepare(
        "SELECT id, name, chain_hops_json, proxy_id, owner_device, created_at, updated_at
         FROM egress_profiles ORDER BY name COLLATE NOCASE",
    )?;
    let rows = stmt.query_map([], row_to_profile)?;
    let mut out = Vec::new();
    for r in rows {
        out.push(r??);
    }
    Ok(out)
}

pub fn get(conn: &Connection, id: &str) -> Result<Option<EgressProfile>, EgressError> {
    let row = conn
        .query_row(
            "SELECT id, name, chain_hops_json, proxy_id, owner_device, created_at, updated_at
             FROM egress_profiles WHERE id = ?1",
            params![id],
            row_to_profile,
        )
        .optional()?;
    Ok(row.transpose()?)
}

/// Insert or update (UPSERT) a profile. Returns
/// `EgressError::DuplicateName` if the (name, owner_device) pair
/// collides with an existing row that isn't this one.
pub fn save(conn: &Connection, profile: &EgressProfile) -> Result<(), EgressError> {
    // Manual conflict detection on (name, owner_device) so we get a
    // typed error rather than relying on a UNIQUE constraint that
    // we'd have to drop for sync-merge semantics later.
    let collision: Option<String> = conn
        .query_row(
            "SELECT id FROM egress_profiles
             WHERE name = ?1
               AND IFNULL(owner_device, '') = IFNULL(?2, '')
               AND id <> ?3",
            params![profile.name, profile.owner_device, profile.id],
            |r| r.get(0),
        )
        .optional()?;
    if collision.is_some() {
        return Err(EgressError::DuplicateName(profile.name.clone()));
    }

    let hops_json = serde_json::to_string(&profile.chain_hops)?;
    conn.execute(
        "INSERT INTO egress_profiles
            (id, name, chain_hops_json, proxy_id, owner_device, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
         ON CONFLICT(id) DO UPDATE SET
            name           = excluded.name,
            chain_hops_json= excluded.chain_hops_json,
            proxy_id       = excluded.proxy_id,
            owner_device   = excluded.owner_device,
            updated_at     = excluded.updated_at",
        params![
            profile.id,
            profile.name,
            hops_json,
            profile.proxy_id,
            profile.owner_device,
            profile.created_at,
            profile.updated_at,
        ],
    )?;
    Ok(())
}

/// Delete a profile. Any `servers.egress_profile_id` rows pointing
/// at it are first set to NULL so dangling bindings don't survive —
/// the column was added in migration #28 without an FK clause
/// (SQLite enforces FKs only when the user opts in), so cascade
/// must be done in code.
pub fn delete(conn: &Connection, id: &str) -> Result<(), EgressError> {
    let has_server_link = conn
        .query_row(
            "SELECT 1 FROM pragma_table_info('servers') WHERE name = 'egress_profile_id'",
            [],
            |_| Ok(()),
        )
        .optional()?
        .is_some();
    if has_server_link {
        conn.execute(
            "UPDATE servers SET egress_profile_id = NULL WHERE egress_profile_id = ?1",
            params![id],
        )?;
    }
    let n = conn.execute("DELETE FROM egress_profiles WHERE id = ?1", params![id])?;
    if n == 0 {
        return Err(EgressError::NotFound(id.to_string()));
    }
    Ok(())
}

/// Summary view; tolerates the absence of a `servers.egress_profile_id`
/// column (returns bound_server_count=0 in that case) so the helper
/// can run on a stand-alone DB used by the test suite.
pub fn list_summaries(conn: &Connection) -> Result<Vec<EgressProfileSummary>, EgressError> {
    let has_server_link = conn
        .query_row(
            "SELECT 1 FROM pragma_table_info('servers') WHERE name = 'egress_profile_id'",
            [],
            |_| Ok(()),
        )
        .optional()?
        .is_some();

    let profiles = list(conn)?;
    let mut out = Vec::with_capacity(profiles.len());
    for p in profiles {
        let bound = if has_server_link {
            conn.query_row(
                "SELECT COUNT(*) FROM servers WHERE egress_profile_id = ?1",
                params![p.id],
                |r| r.get::<_, i64>(0),
            )
            .unwrap_or(0) as usize
        } else {
            0
        };
        out.push(EgressProfileSummary {
            id: p.id,
            name: p.name,
            hop_count: p.chain_hops.len(),
            has_proxy: p.proxy_id.is_some(),
            bound_server_count: bound,
        });
    }
    Ok(out)
}

/// Bind a server to a profile (or clear binding when `profile_id` is
/// None). Creates the `egress_profile_id` column on `servers` if it
/// doesn't exist yet so tests can run on an in-memory DB without
/// the full migration runner.
pub fn bind_server(
    conn: &Connection,
    server_id: &str,
    profile_id: Option<&str>,
) -> Result<(), EgressError> {
    ensure_server_column(conn)?;
    let n = conn.execute(
        "UPDATE servers SET egress_profile_id = ?1 WHERE id = ?2",
        params![profile_id, server_id],
    )?;
    if n == 0 {
        return Err(EgressError::NotFound(server_id.to_string()));
    }
    Ok(())
}

fn ensure_server_column(conn: &Connection) -> Result<(), EgressError> {
    let exists: Option<()> = conn
        .query_row(
            "SELECT 1 FROM pragma_table_info('servers') WHERE name = 'egress_profile_id'",
            [],
            |_| Ok(()),
        )
        .optional()?;
    if exists.is_none() {
        // Live `servers` table is owned by the migration runner; in
        // tests it might not exist at all. Create a minimal one if
        // needed so binding tests don't have to set up the full
        // server schema.
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS servers (
                id   TEXT PRIMARY KEY,
                name TEXT
             );
             ALTER TABLE servers ADD COLUMN egress_profile_id TEXT;",
        )
        .ok();
    }
    Ok(())
}

type RowResult = Result<EgressProfile, EgressError>;

fn row_to_profile(row: &rusqlite::Row) -> rusqlite::Result<RowResult> {
    let hops_json: String = row.get(2)?;
    let parsed: Result<Vec<HopRef>, _> = serde_json::from_str(&hops_json);
    let id: String = row.get(0)?;
    let name: String = row.get(1)?;
    let proxy_id: Option<String> = row.get(3)?;
    let owner_device: Option<String> = row.get(4)?;
    let created_at: String = row.get(5)?;
    let updated_at: String = row.get(6)?;
    let hops = match parsed {
        Ok(h) => h,
        Err(e) => return Ok(Err(EgressError::Json(e))),
    };
    Ok(Ok(EgressProfile {
        id,
        name,
        chain_hops: hops,
        proxy_id,
        owner_device,
        created_at,
        updated_at,
    }))
}
