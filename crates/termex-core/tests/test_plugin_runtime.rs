//! Integration tests for the Rhai-based plugin sandbox.
//!
//! Disabled: `plugin::runtime` is not wired into `plugin::mod` and the
//! `rhai` crate is not listed in `Cargo.toml`. Re-enable once the plugin
//! runtime is officially shipped.
#![cfg(feature = "plugin_runtime")]

use termex_core::plugin::runtime::{run_source, PluginExecutionResult};

#[test]
fn captures_output_via_output_fn() {
    let r: PluginExecutionResult =
        run_source(r#"output("hello, " + input())"#, "world").expect("run");
    assert_eq!(r.output, "hello, world");
}

#[test]
fn captures_log_lines() {
    let r = run_source(
        r#"
            log("a");
            log("b");
            output(input());
        "#,
        "x",
    )
    .expect("run");
    assert_eq!(r.log_lines, vec!["a".to_string(), "b".to_string()]);
    assert_eq!(r.output, "x");
}

#[test]
fn aborts_runaway_loop_within_budget() {
    // An obvious infinite loop must not hang the host. The runtime aborts
    // it via the operations-count cap or the wall-clock progress cb.
    let result = run_source(r#"loop { let x = 1; }"#, "");
    assert!(result.is_err(), "expected runaway loop to abort, got {result:?}");
}

#[test]
fn rejects_unknown_host_function() {
    // Plugins must not be able to call host primitives that haven't been
    // explicitly registered.
    let result = run_source(r#"open("/etc/passwd")"#, "");
    assert!(result.is_err(), "expected open() call to fail (no such host fn)");
}

#[test]
fn empty_script_is_valid() {
    let r = run_source("", "ignored").expect("empty script");
    assert!(r.output.is_empty());
    assert!(r.log_lines.is_empty());
}

#[test]
fn supports_basic_string_manipulation() {
    let r = run_source(
        r#"
            let n = input();
            output(n.to_upper());
        "#,
        "hello",
    )
    .expect("run");
    assert_eq!(r.output, "HELLO");
}
