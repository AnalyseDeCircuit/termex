use termex_lib::ai::context::{
    build_context_prompt, ServerContext, ShellContext, TerminalContext,
};
use termex_lib::ai::orchestrator::parse_orchestration_response;

#[test]
fn test_build_context_prompt_full() {
    let ctx = TerminalContext {
        server: ServerContext {
            hostname: "web-prod".to_string(),
            os: "Ubuntu 22.04".to_string(),
            username: "admin".to_string(),
            connection_chain: "local -> bastion -> web-prod".to_string(),
        },
        shell: ShellContext {
            cwd: "/var/log".to_string(),
            last_command: "tail -f syslog".to_string(),
            last_exit_code: Some(0),
            terminal_mode: "normal".to_string(),
        },
        recent_output: "Apr 12 10:00:01 web-prod systemd: Started foo.".to_string(),
        captured_at: "2026-04-12T10:00:01Z".to_string(),
    };

    let prompt = build_context_prompt("You are an assistant.", &ctx);
    assert!(prompt.starts_with("You are an assistant."));
    assert!(prompt.contains("admin@web-prod"));
    assert!(prompt.contains("Ubuntu 22.04"));
    assert!(prompt.contains("CWD: /var/log"));
    assert!(prompt.contains("Last command: tail -f syslog"));
    assert!(prompt.contains("Exit code: 0"));
    assert!(prompt.contains("Started foo."));
}

#[test]
fn test_build_context_prompt_empty_fields() {
    let ctx = TerminalContext {
        server: ServerContext {
            hostname: "".to_string(),
            os: "".to_string(),
            username: "".to_string(),
            connection_chain: "".to_string(),
        },
        shell: ShellContext {
            cwd: "".to_string(),
            last_command: "".to_string(),
            last_exit_code: None,
            terminal_mode: "".to_string(),
        },
        recent_output: "".to_string(),
        captured_at: "".to_string(),
    };

    let prompt = build_context_prompt("Base prompt.", &ctx);
    assert!(prompt.starts_with("Base prompt."));
    // Empty hostname → no server line
    assert!(!prompt.contains("Server:"));
    assert!(!prompt.contains("CWD:"));
    assert!(!prompt.contains("Last command:"));
    assert!(!prompt.contains("Exit code:"));
    assert!(!prompt.contains("Recent Terminal Output"));
}

#[test]
fn test_build_context_prompt_no_exit_code() {
    let ctx = TerminalContext {
        server: ServerContext {
            hostname: "host".to_string(),
            os: "Linux".to_string(),
            username: "user".to_string(),
            connection_chain: "direct".to_string(),
        },
        shell: ShellContext {
            cwd: "/home".to_string(),
            last_command: "ls".to_string(),
            last_exit_code: None,
            terminal_mode: "normal".to_string(),
        },
        recent_output: "".to_string(),
        captured_at: "".to_string(),
    };

    let prompt = build_context_prompt("P", &ctx);
    assert!(prompt.contains("user@host"));
    assert!(!prompt.contains("Exit code:"));
    assert!(!prompt.contains("Recent Terminal Output"));
}

#[test]
fn test_parse_orchestration_single_step() {
    let content = "STEP 1: Update packages\n```bash\nsudo apt update\n```";
    let steps = parse_orchestration_response(content);
    assert_eq!(steps.len(), 1);
    assert_eq!(steps[0].step_number, 1);
    assert_eq!(steps[0].description, "Update packages");
    assert_eq!(steps[0].command, "sudo apt update");
    assert!(!steps[0].dangerous);
}

#[test]
fn test_parse_orchestration_multi_step() {
    let content = "\
STEP 1: Update packages
```bash
sudo apt update
```

STEP 2: Install nginx
```bash
sudo apt install -y nginx
```

STEP 3: Check status
```bash
systemctl status nginx
```";

    let steps = parse_orchestration_response(content);
    assert_eq!(steps.len(), 3);
    assert_eq!(steps[0].step_number, 1);
    assert_eq!(steps[1].step_number, 2);
    assert_eq!(steps[2].step_number, 3);
    assert_eq!(steps[2].command, "systemctl status nginx");
}

#[test]
fn test_parse_orchestration_dangerous_step() {
    let content = "STEP 1: Remove old files\n```bash\nrm -rf /tmp/old\n```";
    let steps = parse_orchestration_response(content);
    assert_eq!(steps.len(), 1);
    assert!(steps[0].dangerous);
}

#[test]
fn test_parse_orchestration_empty() {
    let content = "No steps here, just plain text.";
    let steps = parse_orchestration_response(content);
    assert!(steps.is_empty());
}
