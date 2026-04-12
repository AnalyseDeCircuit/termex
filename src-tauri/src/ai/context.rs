use serde::Deserialize;

/// Terminal context sent from frontend for AI conversations.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TerminalContext {
    pub server: ServerContext,
    pub shell: ShellContext,
    pub recent_output: String,
    pub captured_at: String,
}

/// Server metadata for AI context (no credentials).
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerContext {
    pub hostname: String,
    pub os: String,
    pub username: String,
    pub connection_chain: String,
}

/// Shell state for AI context.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ShellContext {
    pub cwd: String,
    pub last_command: String,
    pub last_exit_code: Option<i32>,
    pub terminal_mode: String,
}

/// Builds a system prompt with terminal context injected.
pub fn build_context_prompt(base_prompt: &str, ctx: &TerminalContext) -> String {
    let mut prompt = String::with_capacity(base_prompt.len() + 512);
    prompt.push_str(base_prompt);
    prompt.push_str("\n\n--- Terminal Context ---\n");

    if !ctx.server.hostname.is_empty() {
        prompt.push_str(&format!(
            "Server: {}@{} ({})\nConnection: {}\n",
            ctx.server.username, ctx.server.hostname,
            ctx.server.os, ctx.server.connection_chain,
        ));
    }

    if !ctx.shell.cwd.is_empty() {
        prompt.push_str(&format!("CWD: {}\n", ctx.shell.cwd));
    }
    if !ctx.shell.last_command.is_empty() {
        prompt.push_str(&format!("Last command: {}\n", ctx.shell.last_command));
    }
    if let Some(code) = ctx.shell.last_exit_code {
        prompt.push_str(&format!("Exit code: {}\n", code));
    }

    if !ctx.recent_output.is_empty() {
        prompt.push_str(&format!(
            "\n--- Recent Terminal Output ---\n{}\n--- End Output ---\n",
            ctx.recent_output
        ));
    }

    prompt
}
