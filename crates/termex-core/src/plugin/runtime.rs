//! Plugin runtime — minimal Rhai-based sandbox.
//!
//! Loads a plugin entry script (.rhai) and executes it with a confined set
//! of host-provided functions. The sandbox is conservative by design:
//! plugins cannot touch the filesystem, network, or process state directly;
//! everything goes through host-bridged functions whose availability is
//! gated by the manifest's `permissions` field.
//!
//! v0.62 scope (minimum viable):
//!   - `input()` -> String          : the data the host provided to run()
//!   - `output(s: String)`          : appends to the result buffer
//!   - `log(s: String)`             : sends to host log
//!
//! Future permissions hook into the same engine instance:
//!   - terminal_read/write          : send keystrokes / read scrollback
//!   - server_info                  : read host/port/username metadata
//!   - storage                      : per-plugin scoped k/v
//!   - network                      : HTTP via reqwest with allowlist
//!
//! Scripts execute synchronously on the calling thread; long-running
//! operations should be split across multiple `run()` calls or use Rhai's
//! built-in async (not yet enabled here).

use std::path::Path;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use rhai::{Engine, Scope, AST};

use super::PluginError;

/// Result of a plugin execution.
#[derive(Debug, Clone)]
pub struct PluginExecutionResult {
    /// Captured output appended via `output()` calls.
    pub output: String,
    /// Captured log lines appended via `log()` calls.
    pub log_lines: Vec<String>,
    /// How long the script ran.
    pub duration: Duration,
}

/// Maximum wall-clock time a single plugin run is allowed to consume.
/// Rhai's `progress` callback aborts the script when this is exceeded.
const PLUGIN_TIMEOUT: Duration = Duration::from_secs(2);

/// Maximum number of Rhai operations per run. Combined with the wall
/// timeout this protects against infinite loops in misbehaving plugins.
const PLUGIN_MAX_OPERATIONS: u64 = 5_000_000;

/// Loads and executes a plugin script.
///
/// `script_path` should point to the manifest's `entry` file (resolved
/// against the plugin directory). `input` is delivered to the script via
/// the `input()` function.
pub fn run_script(
    script_path: &Path,
    input: &str,
) -> Result<PluginExecutionResult, PluginError> {
    let source = std::fs::read_to_string(script_path)?;
    run_source(&source, input)
}

/// Same as [`run_script`] but takes the script body directly. Used by
/// the bridge layer when a plugin is being previewed before install.
pub fn run_source(
    source: &str,
    input: &str,
) -> Result<PluginExecutionResult, PluginError> {
    let started = Instant::now();
    let output: Arc<Mutex<String>> = Arc::new(Mutex::new(String::new()));
    let logs: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));

    let mut engine = Engine::new();
    // Hard bounds protecting the host process.
    engine.set_max_operations(PLUGIN_MAX_OPERATIONS);
    engine.set_max_call_levels(64);
    engine.set_max_expr_depths(64, 64);
    engine.set_max_string_size(1024 * 1024); // 1 MiB
    engine.set_max_array_size(10_000);
    engine.set_max_map_size(10_000);

    // Wall-clock guard via the progress callback. Rhai aborts when it
    // returns Some(_).
    let deadline = started + PLUGIN_TIMEOUT;
    engine.on_progress(move |_ops| {
        if Instant::now() > deadline {
            Some("plugin exceeded wall-clock budget".into())
        } else {
            None
        }
    });

    // Host functions exposed to the script.
    let input_str = input.to_string();
    engine.register_fn("input", move || -> String { input_str.clone() });

    {
        let buf = Arc::clone(&output);
        engine.register_fn("output", move |s: String| {
            if let Ok(mut g) = buf.lock() {
                g.push_str(&s);
            }
        });
    }
    {
        let buf = Arc::clone(&logs);
        engine.register_fn("log", move |s: String| {
            if let Ok(mut g) = buf.lock() {
                g.push(s);
            }
        });
    }

    let ast: AST = engine
        .compile(source)
        .map_err(|e| PluginError::InvalidManifest(format!("compile error: {e}")))?;

    let mut scope = Scope::new();
    engine
        .run_ast_with_scope(&mut scope, &ast)
        .map_err(|e| PluginError::InvalidManifest(format!("runtime error: {e}")))?;

    let out = output.lock().map(|g| g.clone()).unwrap_or_default();
    let log_lines = logs.lock().map(|g| g.clone()).unwrap_or_default();

    Ok(PluginExecutionResult {
        output: out,
        log_lines,
        duration: started.elapsed(),
    })
}
