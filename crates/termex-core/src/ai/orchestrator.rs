use serde::{Deserialize, Serialize};

/// A parsed step from AI orchestration response.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ParsedStep {
    pub step_number: u32,
    pub description: String,
    pub command: String,
    pub dangerous: bool,
}

/// Parses AI response into structured command steps.
///
/// Expected format:
/// ```text
/// STEP 1: Description
/// ```bash
/// command
/// ```
/// ```
pub fn parse_orchestration_response(content: &str) -> Vec<ParsedStep> {
    let mut steps = Vec::new();
    let step_re = regex::Regex::new(
        r"(?i)STEP\s+(\d+)[:\s]+(.+?)(?:\r?\n)```(?:bash|sh|shell)?\n([\s\S]*?)```",
    )
    .expect("valid orchestration regex");

    for cap in step_re.captures_iter(content) {
        let step_num: u32 = cap[1].parse().unwrap_or(0);
        let desc = cap[2].trim().to_string();
        let cmd = cap[3].trim().to_string();

        let danger = crate::ai::danger::DangerDetector::new().check(&cmd);

        steps.push(ParsedStep {
            step_number: step_num,
            description: desc,
            command: cmd,
            dangerous: danger.is_dangerous,
        });
    }
    steps
}

/// System prompt for orchestration requests.
pub const ORCHESTRATION_PROMPT: &str = "\
You are Termex AI, an expert operations assistant. \
The user will describe a goal. Generate a step-by-step command sequence. \
\n\nFormat EXACTLY as:\n\
STEP 1: <description>\n```bash\n<command>\n```\n\n\
STEP 2: <description>\n```bash\n<command>\n```\n\n\
Rules:\n\
- One command per step (pipe chains are OK)\n\
- Include error checking where appropriate\n\
- Use sudo only when necessary\n\
- Prefer non-destructive commands\n\
- Maximum 15 steps";
