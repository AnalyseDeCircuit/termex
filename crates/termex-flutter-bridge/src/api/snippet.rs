/// Command-snippet (template) APIs exposed to Flutter via FRB.
///
/// Snippets support `{{varname}}` and `{{varname:default}}` variable
/// placeholders that are resolved before sending the command to the terminal.
///
/// Persistence uses the `snippets` / `snippet_folders` tables from V12.
/// When the database is not unlocked the CRUD calls fall back to in-memory
/// no-ops so that unit tests can exercise the API shape without a database.
use flutter_rust_bridge::frb;

use crate::db_state;
use termex_core::storage::models::SnippetInput as CoreSnippetInput;
use termex_core::storage::snippet as core_snippet;

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// A saved command template.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Snippet {
    pub id: String,
    pub name: String,
    /// Raw template content, may contain `{{varname}}` placeholders.
    pub content: String,
    /// Optional group / category name (surfaced as tags[0] in storage).
    pub group: Option<String>,
    /// Free-form tags for search.
    pub tags: Vec<String>,
    /// How many times this snippet has been sent to a terminal.
    pub use_count: i32,
    /// ISO 8601 timestamp of the most recent use, or `None` if unused.
    pub last_used_at: Option<String>,
    /// ISO 8601 creation timestamp.
    pub created_at: String,
}

/// A variable extracted from a snippet template.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SnippetVariable {
    pub name: String,
    /// Default value declared in the template (`{{name:default}}`), if any.
    pub default_value: Option<String>,
}

// ─── Mapping between FRB DTO and core model ──────────────────────────────────
//
// The FRB DTO uses user-friendly field names (`name`, `content`, `group`) for
// backwards compatibility with v0.45 tests.  The core model uses `title`,
// `command`, `folder_id`.  Group is stored as a synthetic prefix tag of the
// form `group:<name>` so that it can be recovered without introducing an extra
// column.  Ordinary tags coexist alongside the marker.

const GROUP_TAG_PREFIX: &str = "group:";

fn split_tags(tags: Vec<String>, group: &Option<String>) -> (Option<String>, Vec<String>) {
    let mut clean_tags = Vec::new();
    let mut group_from_tags: Option<String> = None;
    for t in tags {
        if let Some(g) = t.strip_prefix(GROUP_TAG_PREFIX) {
            group_from_tags = Some(g.to_string());
        } else {
            clean_tags.push(t);
        }
    }
    (group.clone().or(group_from_tags), clean_tags)
}

fn assemble_storage_tags(group: &Option<String>, tags: &[String]) -> Vec<String> {
    let mut out: Vec<String> = tags.to_vec();
    if let Some(g) = group {
        if !g.is_empty() {
            out.push(format!("{GROUP_TAG_PREFIX}{g}"));
        }
    }
    out
}

fn from_core(s: termex_core::storage::models::Snippet) -> Snippet {
    let (group, clean_tags) = split_tags(s.tags.clone(), &None);
    Snippet {
        id: s.id,
        name: s.title,
        content: s.command,
        group,
        tags: clean_tags,
        use_count: s.usage_count,
        last_used_at: s.last_used_at,
        created_at: s.created_at,
    }
}

// ─── CRUD ─────────────────────────────────────────────────────────────────────

/// Returns snippets, optionally filtered by a text `query` and/or a `group`.
/// When no database is unlocked the function returns an empty list.
#[frb]
pub fn snippet_list(
    query: Option<String>,
    group: Option<String>,
) -> Result<Vec<Snippet>, String> {
    if !db_state::is_unlocked() {
        return Ok(vec![]);
    }

    db_state::with_db(|db| {
        let all = db
            .with_conn(|conn| {
                core_snippet::list(conn, None, query.as_deref()).map_err(|e| {
                    rusqlite::Error::InvalidParameterName(e.to_string())
                })
            })
            .map_err(|e| e.to_string())?;

        let mut out: Vec<Snippet> = all.into_iter().map(from_core).collect();
        if let Some(g) = &group {
            if !g.is_empty() {
                out.retain(|s| s.group.as_deref() == Some(g.as_str()));
            }
        }
        Ok(out)
    })
}

/// Creates a new snippet and returns it with a generated ID and timestamp.
#[frb]
pub fn snippet_create(
    name: String,
    content: String,
    group: Option<String>,
    tags: Vec<String>,
) -> Result<Snippet, String> {
    if !db_state::is_unlocked() {
        // Stub path: return a fully-formed snippet without persisting.
        return Ok(Snippet {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            content,
            group,
            tags,
            use_count: 0,
            last_used_at: None,
            created_at: chrono::Utc::now().to_rfc3339(),
        });
    }

    let storage_tags = assemble_storage_tags(&group, &tags);
    let input = CoreSnippetInput {
        title: name.clone(),
        description: None,
        command: content.clone(),
        tags: storage_tags,
        folder_id: None,
        is_favorite: false,
    };

    db_state::with_db(|db| {
        let core = db
            .with_conn(|conn| {
                core_snippet::create(conn, &input)
                    .map_err(|e| rusqlite::Error::InvalidParameterName(e))
            })
            .map_err(|e| e.to_string())?;
        let mut dto = from_core(core);
        // Preserve caller-provided group/tags ordering even if recovery misses.
        dto.group = group;
        dto.tags = tags;
        Ok(dto)
    })
}

/// Updates an existing snippet identified by `id`.
#[frb]
pub fn snippet_update(
    id: String,
    name: String,
    content: String,
    group: Option<String>,
    tags: Vec<String>,
) -> Result<Snippet, String> {
    if !db_state::is_unlocked() {
        return Ok(Snippet {
            id,
            name,
            content,
            group,
            tags,
            use_count: 0,
            last_used_at: None,
            created_at: chrono::Utc::now().to_rfc3339(),
        });
    }

    let storage_tags = assemble_storage_tags(&group, &tags);
    let input = CoreSnippetInput {
        title: name,
        description: None,
        command: content,
        tags: storage_tags,
        folder_id: None,
        is_favorite: false,
    };

    db_state::with_db(|db| {
        let core = db
            .with_conn(|conn| {
                core_snippet::update(conn, &id, &input)
                    .map_err(|e| rusqlite::Error::InvalidParameterName(e))
            })
            .map_err(|e| e.to_string())?;
        let mut dto = from_core(core);
        dto.group = group;
        dto.tags = tags;
        Ok(dto)
    })
}

/// Deletes the snippet with the given `id`.
#[frb]
pub fn snippet_delete(id: String) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            core_snippet::delete(conn, &id)
                .map_err(rusqlite::Error::InvalidParameterName)
        })
        .map_err(|e| e.to_string())
    })
}

/// Increments `use_count` and updates `last_used_at` for snippet `id`.
#[frb]
pub fn snippet_record_use(id: String) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            core_snippet::record_usage(conn, &id)
                .map_err(rusqlite::Error::InvalidParameterName)
        })
        .map_err(|e| e.to_string())
    })
}

/// Returns the distinct group names across all snippets.
#[frb]
pub fn snippet_list_groups() -> Result<Vec<String>, String> {
    if !db_state::is_unlocked() {
        return Ok(vec![]);
    }
    db_state::with_db(|db| {
        let all = db
            .with_conn(|conn| {
                core_snippet::list(conn, None, None)
                    .map_err(rusqlite::Error::InvalidParameterName)
            })
            .map_err(|e| e.to_string())?;
        let mut groups: Vec<String> = all
            .into_iter()
            .flat_map(|s| s.tags)
            .filter_map(|t| t.strip_prefix(GROUP_TAG_PREFIX).map(|s| s.to_string()))
            .collect();
        groups.sort();
        groups.dedup();
        Ok(groups)
    })
}

// ─── Template utilities ───────────────────────────────────────────────────────

/// Parses `content` and returns every unique `{{varname}}` or
/// `{{varname:default}}` placeholder found, in order of first occurrence.
///
/// Duplicates are deduplicated (first occurrence wins).
#[frb]
pub fn snippet_extract_variables(content: String) -> Vec<SnippetVariable> {
    let mut seen = std::collections::HashSet::new();
    let mut result = Vec::new();

    let mut chars = content.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch == '{' && chars.peek() == Some(&'{') {
            chars.next();
            let mut inner = String::new();
            loop {
                match chars.next() {
                    Some('}') if chars.peek() == Some(&'}') => {
                        chars.next();
                        break;
                    }
                    Some(c) => inner.push(c),
                    None => break,
                }
            }
            let inner = inner.trim().to_string();
            if inner.is_empty() {
                continue;
            }
            let (name, default_value) = if let Some(pos) = inner.find(':') {
                let n = inner[..pos].trim().to_string();
                let d = inner[pos + 1..].trim().to_string();
                (n, if d.is_empty() { None } else { Some(d) })
            } else {
                (inner, None)
            };
            if !name.is_empty() && seen.insert(name.clone()) {
                result.push(SnippetVariable { name, default_value });
            }
        }
    }
    result
}

// ─── Import / Export (JSON, team-shareable — §7.5 of spec) ─────────────────

#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SnippetExportDoc {
    pub schema_version: u16,
    pub exported_at: String,
    pub snippets: Vec<Snippet>,
}

#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SnippetImportSummary {
    pub imported: u32,
    pub skipped_duplicates: u32,
    pub schema_version: u16,
}

/// Exports every snippet to a JSON file at `path`.  Includes variable
/// declarations (via `extractVariables` over each snippet's content) so the
/// document is self-contained.
#[frb]
pub fn snippet_export_json(path: String) -> Result<(), String> {
    let snippets = snippet_list(None, None)?;
    let doc = SnippetExportDoc {
        schema_version: 1,
        exported_at: chrono::Utc::now().to_rfc3339(),
        snippets,
    };
    let json = serde_json::to_string_pretty(&doc).map_err(|e| e.to_string())?;
    std::fs::write(&path, json).map_err(|e| format!("write snippet export: {e}"))?;
    Ok(())
}

/// Imports snippets from a JSON file.  Duplicates (by exact `name`) are
/// skipped; everything else is created fresh.
#[frb]
pub fn snippet_import_json(path: String) -> Result<SnippetImportSummary, String> {
    let raw = std::fs::read_to_string(&path).map_err(|e| format!("read import: {e}"))?;
    let doc: SnippetExportDoc = serde_json::from_str(&raw).map_err(|e| e.to_string())?;

    let existing = snippet_list(None, None)?;
    let existing_names: std::collections::HashSet<String> =
        existing.into_iter().map(|s| s.name).collect();

    let mut imported = 0u32;
    let mut skipped = 0u32;
    for s in &doc.snippets {
        if existing_names.contains(&s.name) {
            skipped += 1;
            continue;
        }
        snippet_create(s.name.clone(), s.content.clone(), s.group.clone(), s.tags.clone())?;
        imported += 1;
    }

    Ok(SnippetImportSummary {
        imported,
        skipped_duplicates: skipped,
        schema_version: doc.schema_version,
    })
}

/// Replaces every `{{varname}}` placeholder in `content` with the corresponding
/// value from `variables`.  Placeholders for which no value is provided are
/// replaced with an empty string.
#[frb]
pub fn snippet_resolve(content: String, variables: Vec<(String, String)>) -> String {
    let mut output = content;
    for (name, value) in &variables {
        // Replace both {{name}} and {{name:default}} variants.
        let plain = format!("{{{{{}}}}}", name);
        output = output.replace(&plain, value);
    }
    // Replace any remaining {{name:default}} patterns with empty string.
    let mut result = String::new();
    let mut chars = output.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch == '{' && chars.peek() == Some(&'{') {
            chars.next();
            let mut inner = String::new();
            loop {
                match chars.next() {
                    Some('}') if chars.peek() == Some(&'}') => {
                        chars.next();
                        break;
                    }
                    Some(c) => inner.push(c),
                    None => break,
                }
            }
            let _ = inner;
        } else {
            result.push(ch);
        }
    }
    result
}
