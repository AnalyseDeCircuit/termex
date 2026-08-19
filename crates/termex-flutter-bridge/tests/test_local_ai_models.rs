//! Model discovery across the directories two generations of the product used.
//!
//! The Flutter port read `data_dir()/models` while the Tauri build wrote
//! `paths::models_dir()`, and it shrank the catalogue from twelve entries to
//! three under different ids. Between them, a user who had already downloaded
//! a model saw an empty list and a server that would not start.

use termex_flutter_bridge::local_ai_state::{
    catalog_lookup, MODEL_CATALOG,
};

#[test]
fn the_catalogue_carries_every_model_the_tauri_build_offered() {
    // Ids are the on-disk filenames; dropping one strands a downloaded file.
    let expected = [
        "tinyllama-1.1b-q2",
        "qwen2.5-0.5b-q3",
        "phi-2-q2",
        "qwen2.5-0.5b-q4",
        "phi-3-3b-q3",
        "mobilequwen-0.5b-q4",
        "llama3.2-3b-q4",
        "qwen2.5-3b-q4",
        "phi-3-3b-q4",
        "qwen2.5-7b-q4",
        "llama3.3-8b-q4",
        "deepseek-7b-q4",
    ];
    assert_eq!(MODEL_CATALOG.len(), expected.len());
    for id in expected {
        assert!(catalog_lookup(id).is_some(), "catalogue lost {id}");
    }
}

#[test]
fn every_entry_names_its_file_after_its_id() {
    for e in MODEL_CATALOG {
        assert_eq!(
            e.filename,
            format!("{}.gguf", e.id),
            "{} would not be found on disk",
            e.id
        );
    }
}

#[test]
fn the_catalogue_keeps_the_fields_the_old_list_displayed() {
    for e in MODEL_CATALOG {
        assert!(!e.display_name.is_empty(), "{} has no name", e.id);
        assert!(e.min_ram_gb > 0, "{} has no RAM requirement", e.id);
        assert!(e.context_length > 0, "{} has no context length", e.id);
        assert!(e.size_bytes > 0, "{} has no size", e.id);
        assert!(e.url.starts_with("https://"), "{} has no download", e.id);
    }
}

#[test]
fn exactly_one_entry_is_recommended() {
    let n = MODEL_CATALOG.iter().filter(|e| e.recommended).count();
    assert_eq!(n, 1, "the list needs one default suggestion");
}

// ── Discovery on disk ────────────────────────────────────────────────────────

use std::sync::{Mutex, OnceLock};
use termex_flutter_bridge::local_ai_state::{
    find_model_file, model_download_dir, model_search_dirs, scan_downloaded_models,
};

static DISK_LOCK: Mutex<()> = Mutex::new(());
static ROOT: OnceLock<tempfile::TempDir> = OnceLock::new();

/// Points the core's path helpers at a temp root, once per test process.
/// `app_dir()` becomes `<root>` and `data_dir()` `<root>/data`, which is the
/// same split the real install has — the whole point of the fix.
fn root() -> &'static std::path::Path {
    let dir = ROOT.get_or_init(|| {
        let d = tempfile::TempDir::new().unwrap();
        termex_core::paths::override_app_data_dir(d.path().to_path_buf());
        d
    });
    dir.path()
}

fn write_model(dir: &std::path::Path, name: &str, bytes: usize) {
    std::fs::create_dir_all(dir).unwrap();
    std::fs::write(dir.join(name), vec![0u8; bytes]).unwrap();
}

fn clear_models() {
    for d in model_search_dirs() {
        if let Ok(entries) = std::fs::read_dir(&d) {
            for e in entries.flatten() {
                let _ = std::fs::remove_file(e.path());
            }
        }
    }
}

#[test]
fn the_two_generations_of_model_directory_are_both_searched() {
    let _lock = DISK_LOCK.lock().unwrap();
    let _ = root();
    let dirs = model_search_dirs();
    assert_eq!(dirs.len(), 2, "legacy directory dropped from the search");
    assert_eq!(dirs[0], termex_core::paths::models_dir());
    assert_eq!(dirs[1], termex_core::paths::data_dir().join("models"));
}

#[test]
fn downloads_are_written_to_the_canonical_directory() {
    let _lock = DISK_LOCK.lock().unwrap();
    let _ = root();
    // Not data_dir()/models, which is where the port had been putting them —
    // out of sight of every other consumer of paths::models_dir().
    assert_eq!(model_download_dir(), termex_core::paths::models_dir());
}

#[test]
fn a_model_left_by_the_old_build_is_found() {
    let _lock = DISK_LOCK.lock().unwrap();
    let r = root();
    clear_models();
    // Exactly what the Tauri build wrote: canonical dir, catalogue id.
    write_model(&r.join("models"), "qwen2.5-7b-q4.gguf", 32);

    let found = find_model_file("qwen2.5-7b-q4.gguf").expect("not found");
    assert!(found.is_file());

    let scanned = scan_downloaded_models();
    assert_eq!(scanned.len(), 1);
    assert_eq!(scanned[0].0, "qwen2.5-7b-q4");
    assert_eq!(scanned[0].2, 32, "size should come from the file");
}

#[test]
fn a_model_this_build_downloaded_to_the_wrong_place_still_counts() {
    let _lock = DISK_LOCK.lock().unwrap();
    let r = root();
    clear_models();
    write_model(&r.join("data").join("models"), "phi-2-q2.gguf", 16);

    assert!(find_model_file("phi-2-q2.gguf").is_some(),
        "models already downloaded by the Flutter build must not be orphaned");
}

#[test]
fn the_canonical_copy_wins_when_both_directories_have_one() {
    let _lock = DISK_LOCK.lock().unwrap();
    let r = root();
    clear_models();
    write_model(&r.join("models"), "phi-3-3b-q4.gguf", 8);
    write_model(&r.join("data").join("models"), "phi-3-3b-q4.gguf", 99);

    let scanned = scan_downloaded_models();
    assert_eq!(scanned.len(), 1, "the same model listed twice");
    assert_eq!(scanned[0].2, 8, "should prefer the canonical directory");
}

#[test]
fn a_model_no_catalogue_entry_describes_is_still_listed() {
    let _lock = DISK_LOCK.lock().unwrap();
    let r = root();
    clear_models();
    // An id from a catalogue generation neither build ships any more.
    write_model(&r.join("models"), "some-retired-model-q5.gguf", 4);

    let scanned = scan_downloaded_models();
    assert!(scanned.iter().any(|(id, _, _)| id == "some-retired-model-q5"),
        "a file the user already has must not be hidden");
    assert!(catalog_lookup("some-retired-model-q5").is_none());
}

#[test]
fn non_model_files_are_ignored() {
    let _lock = DISK_LOCK.lock().unwrap();
    let r = root();
    clear_models();
    write_model(&r.join("models"), "notes.txt", 4);
    write_model(&r.join("models"), "phi-2-q2.gguf.tmp", 4);

    assert!(scan_downloaded_models().is_empty(),
        "only .gguf files are models");
}
