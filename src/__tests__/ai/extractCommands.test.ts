import { describe, it, expect } from "vitest";

// Inline the function to test (same logic as aiStore.extractCommands)
function extractCommands(content: string) {
  const commands: Array<{
    command: string;
    description: string;
    dangerous: boolean;
  }> = [];
  const regex = /```(?:bash|sh|shell)?\n([\s\S]*?)```/g;
  let match: RegExpExecArray | null;
  while ((match = regex.exec(content)) !== null) {
    const cmd = match[1].trim();
    if (cmd) {
      commands.push({ command: cmd, description: "", dangerous: false });
    }
  }
  return commands;
}

describe("extractCommands", () => {
  it("extracts single bash block", () => {
    const content = "Run this:\n```bash\nsudo apt update\n```";
    const cmds = extractCommands(content);
    expect(cmds).toHaveLength(1);
    expect(cmds[0].command).toBe("sudo apt update");
  });

  it("extracts multiple blocks", () => {
    const content = "First:\n```bash\nls -la\n```\nThen:\n```bash\ndf -h\n```";
    const cmds = extractCommands(content);
    expect(cmds).toHaveLength(2);
    expect(cmds[0].command).toBe("ls -la");
    expect(cmds[1].command).toBe("df -h");
  });

  it("handles sh and shell language tags", () => {
    const content = "```sh\necho hello\n```\n```shell\necho world\n```";
    const cmds = extractCommands(content);
    expect(cmds).toHaveLength(2);
  });

  it("handles block without language tag", () => {
    const content = "```\necho no-lang\n```";
    const cmds = extractCommands(content);
    expect(cmds).toHaveLength(1);
    expect(cmds[0].command).toBe("echo no-lang");
  });

  it("ignores non-bash blocks", () => {
    const content = '```json\n{"key": "value"}\n```';
    const cmds = extractCommands(content);
    expect(cmds).toHaveLength(0);
  });

  it("handles empty blocks", () => {
    const content = "```bash\n\n```";
    const cmds = extractCommands(content);
    expect(cmds).toHaveLength(0);
  });

  it("returns empty for plain text", () => {
    const content = "Just some text, no code blocks.";
    const cmds = extractCommands(content);
    expect(cmds).toHaveLength(0);
  });
});
