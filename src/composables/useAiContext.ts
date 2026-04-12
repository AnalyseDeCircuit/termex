import { type Ref } from "vue";
import type { Terminal } from "@xterm/xterm";
import type { TerminalContext, ContextOptions } from "@/types/aiContext";
import { DEFAULT_CONTEXT_OPTIONS } from "@/types/aiContext";
import { useSessionStore } from "@/stores/sessionStore";
import { useServerStore } from "@/stores/serverStore";

export function useAiContext(
  getTerminal: () => Terminal | null,
  sessionId: Ref<string>,
) {
  function captureContext(
    options: ContextOptions = DEFAULT_CONTEXT_OPTIONS,
  ): TerminalContext | null {
    const terminal = getTerminal();
    if (!terminal) return null;

    const sessionStore = useSessionStore();
    const serverStore = useServerStore();
    const session = sessionStore.sessions.get(sessionId.value);
    if (!session) return null;

    const server = serverStore.servers.find((s) => s.id === session.serverId);

    const recentOutput = options.includeOutput
      ? extractRecentLines(terminal, options.outputLines)
      : "";

    return {
      server: options.includeServer
        ? {
            hostname: server?.host ?? "unknown",
            os: "unknown",
            username: server?.username ?? "unknown",
            connectionChain: session.serverId ?? "direct",
          }
        : { hostname: "", os: "", username: "", connectionChain: "" },
      shell: options.includeShell
        ? {
            cwd: extractCwd(terminal),
            lastCommand: "",
            lastExitCode: null,
            terminalMode: "normal",
          }
        : { cwd: "", lastCommand: "", lastExitCode: null, terminalMode: "unknown" },
      recentOutput,
      capturedAt: new Date().toISOString(),
    };
  }

  return { captureContext };
}

export function extractRecentLines(terminal: Terminal, count: number): string {
  const buffer = terminal.buffer.active;
  const lines: string[] = [];
  const end = buffer.cursorY + buffer.baseY;
  const start = Math.max(0, end - count);

  for (let i = start; i <= end; i++) {
    const line = buffer.getLine(i);
    if (line) {
      lines.push(line.translateToString(true));
    }
  }
  return lines.join("\n");
}

function extractCwd(terminal: Terminal): string {
  const buffer = terminal.buffer.active;
  const cursorLine = buffer.getLine(buffer.cursorY + buffer.baseY);
  if (!cursorLine) return "unknown";

  const text = cursorLine.translateToString(true);
  const match = text.match(/[:]\s*(~?\/[^\s$#]*)/);
  if (match) return match[1];

  const match2 = text.match(/\s(~?\/[^\s\]$#]*)/);
  if (match2) return match2[1];

  return "unknown";
}
