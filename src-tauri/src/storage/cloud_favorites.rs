use rusqlite::Connection;

/// A saved reference to a cloud resource (K8s context or AWS SSM profile)
/// that can be shared with the team.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloudFavorite {
    pub id: String,
    /// Human-readable display name.
    pub name: String,
    /// "kube" or "ssm"
    pub resource_type: String,
    /// K8s context name or AWS profile name.
    pub context_or_profile: String,
    /// Default namespace (kube only, optional).
    pub namespace: Option<String>,
    /// AWS region (ssm only, optional).
    pub region: Option<String>,
    pub shared: bool,
    pub team_id: Option<String>,
    pub shared_by: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// Input for creating a cloud favorite.
#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloudFavoriteInput {
    pub name: String,
    pub resource_type: String,
    pub context_or_profile: String,
    pub namespace: Option<String>,
    pub region: Option<String>,
}

/// Lists all cloud favorites.
pub fn list(conn: &Connection) -> Result<Vec<CloudFavorite>, rusqlite::Error> {
    let mut stmt = conn.prepare(
        "SELECT id, name, resource_type, context_or_profile, namespace, region,
                shared, team_id, shared_by, created_at, updated_at
         FROM cloud_favorites ORDER BY resource_type, name",
    )?;
    let rows = stmt
        .query_map([], row_to_favorite)?
        .filter_map(|r| r.ok())
        .collect();
    Ok(rows)
}

/// Gets a cloud favorite by ID.
pub fn get(conn: &Connection, id: &str) -> Result<Option<CloudFavorite>, rusqlite::Error> {
    let mut stmt = conn.prepare(
        "SELECT id, name, resource_type, context_or_profile, namespace, region,
                shared, team_id, shared_by, created_at, updated_at
         FROM cloud_favorites WHERE id = ?1",
    )?;
    match stmt.query_row(rusqlite::params![id], row_to_favorite) {
        Ok(f) => Ok(Some(f)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e),
    }
}

/// Finds an existing favorite by resource type + context/profile name.
pub fn find_by_ref(
    conn: &Connection,
    resource_type: &str,
    context_or_profile: &str,
) -> Result<Option<CloudFavorite>, rusqlite::Error> {
    let mut stmt = conn.prepare(
        "SELECT id, name, resource_type, context_or_profile, namespace, region,
                shared, team_id, shared_by, created_at, updated_at
         FROM cloud_favorites
         WHERE resource_type = ?1 AND context_or_profile = ?2
         LIMIT 1",
    )?;
    match stmt.query_row(rusqlite::params![resource_type, context_or_profile], row_to_favorite) {
        Ok(f) => Ok(Some(f)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e),
    }
}

/// Creates a new cloud favorite.
pub fn create(conn: &Connection, input: &CloudFavoriteInput) -> Result<CloudFavorite, rusqlite::Error> {
    let id = uuid::Uuid::new_v4().to_string();
    let now = time::OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap_or_default();
    conn.execute(
        "INSERT INTO cloud_favorites
         (id, name, resource_type, context_or_profile, namespace, region,
          shared, team_id, shared_by, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, 0, NULL, NULL, ?7, ?8)",
        rusqlite::params![
            id, input.name, input.resource_type, input.context_or_profile,
            input.namespace, input.region, now, now,
        ],
    )?;
    Ok(CloudFavorite {
        id,
        name: input.name.clone(),
        resource_type: input.resource_type.clone(),
        context_or_profile: input.context_or_profile.clone(),
        namespace: input.namespace.clone(),
        region: input.region.clone(),
        shared: false,
        team_id: None,
        shared_by: None,
        created_at: now.clone(),
        updated_at: now,
    })
}

/// Deletes a cloud favorite.
pub fn delete(conn: &Connection, id: &str) -> Result<(), rusqlite::Error> {
    conn.execute("DELETE FROM cloud_favorites WHERE id = ?1", rusqlite::params![id])?;
    Ok(())
}

/// Sets whether a cloud favorite is shared with the team.
pub fn set_shared(conn: &Connection, id: &str, shared: bool) -> Result<(), rusqlite::Error> {
    let now = time::OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap_or_default();
    conn.execute(
        "UPDATE cloud_favorites SET shared = ?1, updated_at = ?2 WHERE id = ?3",
        rusqlite::params![shared as i32, now, id],
    )?;
    Ok(())
}

/// Converts a team-received favorite to a locally-owned private favorite.
pub fn make_local(conn: &Connection, id: &str) -> Result<(), rusqlite::Error> {
    let now = time::OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap_or_default();
    conn.execute(
        "UPDATE cloud_favorites SET shared = 0, team_id = NULL, shared_by = NULL, updated_at = ?1 WHERE id = ?2",
        rusqlite::params![now, id],
    )?;
    Ok(())
}

fn row_to_favorite(row: &rusqlite::Row<'_>) -> Result<CloudFavorite, rusqlite::Error> {
    Ok(CloudFavorite {
        id: row.get(0)?,
        name: row.get(1)?,
        resource_type: row.get(2)?,
        context_or_profile: row.get(3)?,
        namespace: row.get(4)?,
        region: row.get(5)?,
        shared: row.get::<_, i32>(6)? != 0,
        team_id: row.get(7)?,
        shared_by: row.get(8)?,
        created_at: row.get(9)?,
        updated_at: row.get(10)?,
    })
}
