use crate::db_state;
use chrono::Utc;
use uuid::Uuid;

/// Server group data transfer object exposed to Flutter.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDto {
    pub id: String,
    pub name: String,
    pub color: String,
    pub icon: String,
    pub parent_id: Option<String>,
    pub sort_order: i32,
    pub created_at: String,
    pub updated_at: String,
}

/// Input payload for creating or updating a server group.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupInput {
    pub name: String,
    pub color: String,
    pub icon: String,
    pub parent_id: Option<String>,
    pub sort_order: i32,
}

/// Lists all server groups ordered by `sort_order`.
pub fn list_groups() -> Result<Vec<GroupDto>, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, color, icon, parent_id, sort_order, created_at, updated_at
                 FROM groups
                 ORDER BY sort_order ASC",
            )?;
            let rows = stmt.query_map([], |row| {
                Ok(GroupDto {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    color: row.get(2)?,
                    icon: row.get(3)?,
                    parent_id: row.get(4)?,
                    sort_order: row.get(5)?,
                    created_at: row.get(6)?,
                    updated_at: row.get(7)?,
                })
            })?;
            rows.collect::<rusqlite::Result<Vec<_>>>()
        })
        .map_err(|e| e.to_string())
    })
}

/// Returns a single group by ID, or `None` if not found.
pub fn get_group(id: String) -> Result<Option<GroupDto>, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let result = conn.query_row(
                "SELECT id, name, color, icon, parent_id, sort_order, created_at, updated_at
                 FROM groups
                 WHERE id = ?1",
                rusqlite::params![id],
                |row| {
                    Ok(GroupDto {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        color: row.get(2)?,
                        icon: row.get(3)?,
                        parent_id: row.get(4)?,
                        sort_order: row.get(5)?,
                        created_at: row.get(6)?,
                        updated_at: row.get(7)?,
                    })
                },
            );
            match result {
                Ok(g) => Ok(Some(g)),
                Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
                Err(e) => Err(e),
            }
        })
        .map_err(|e| e.to_string())
    })
}

/// Creates a new server group, returning the created group.
pub fn create_group(input: GroupInput) -> Result<GroupDto, String> {
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT INTO groups (id, name, color, icon, parent_id, sort_order, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                rusqlite::params![
                    id,
                    input.name,
                    input.color,
                    input.icon,
                    input.parent_id,
                    input.sort_order,
                    now,
                    now,
                ],
            )?;
            Ok(GroupDto {
                id,
                name: input.name,
                color: input.color,
                icon: input.icon,
                parent_id: input.parent_id,
                sort_order: input.sort_order,
                created_at: now.clone(),
                updated_at: now,
            })
        })
        .map_err(|e| e.to_string())
    })
}

/// Updates an existing server group by ID, returning the updated group.
pub fn update_group(id: String, input: GroupInput) -> Result<GroupDto, String> {
    let now = Utc::now().to_rfc3339();

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let rows_affected = conn.execute(
                "UPDATE groups
                 SET name = ?2, color = ?3, icon = ?4, parent_id = ?5,
                     sort_order = ?6, updated_at = ?7
                 WHERE id = ?1",
                rusqlite::params![
                    id,
                    input.name,
                    input.color,
                    input.icon,
                    input.parent_id,
                    input.sort_order,
                    now,
                ],
            )?;
            if rows_affected == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            // Fetch updated row for the correct created_at timestamp
            conn.query_row(
                "SELECT id, name, color, icon, parent_id, sort_order, created_at, updated_at
                 FROM groups WHERE id = ?1",
                rusqlite::params![id],
                |row| {
                    Ok(GroupDto {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        color: row.get(2)?,
                        icon: row.get(3)?,
                        parent_id: row.get(4)?,
                        sort_order: row.get(5)?,
                        created_at: row.get(6)?,
                        updated_at: row.get(7)?,
                    })
                },
            )
        })
        .map_err(|e| e.to_string())
    })
}

/// Deletes a group by ID and NULLifies `group_id` on servers that belonged to it.
pub fn delete_group(id: String) -> Result<(), String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            // Null out group_id on servers in this group
            conn.execute(
                "UPDATE servers SET group_id = NULL WHERE group_id = ?1",
                rusqlite::params![id],
            )?;
            conn.execute("DELETE FROM groups WHERE id = ?1", rusqlite::params![id])?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Updates the `sort_order` of each group according to the provided ordered list of IDs.
///
/// The first ID in `ids` receives `sort_order = 0`, the second receives `1`, and so on.
pub fn reorder_groups(ids: Vec<String>) -> Result<(), String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            for (index, id) in ids.iter().enumerate() {
                conn.execute(
                    "UPDATE groups SET sort_order = ?2 WHERE id = ?1",
                    rusqlite::params![id, index as i32],
                )?;
            }
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}
