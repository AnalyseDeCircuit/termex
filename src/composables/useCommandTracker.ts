import { ref, type Ref } from "vue";
import type { Terminal, IDisposable } from "@xterm/xterm";
import type { CommandLineState, TerminalMode } from "@/types/commandTracker";

/** Matches common shell prompt endings. */
const PROMPT_ENDINGS = [
  /\$\s$/,          // bash: "user@host:~$ "
  /#\s$/,           // root: "root@host:~# "
  /%\s$/,           // zsh: "user% "
  />\s$/,           // fish/powershell: "> "
  />>>\s$/,         // Python REPL
  /\)\s*\$\s$/,     // conda: "(base) user@host:~$ "
  /\)\s*#\s$/,      // conda root
];

/** Detects reverse-i-search mode. */
const REVERSE_SEARCH_RE = /\(reverse-i-search\)/;

/**
 * Composable that tracks the current command line state in a terminal.
 * Reads from the xterm.js buffer (ground truth) rather than local key tracking.
 */
export function useCommandTracker(
  getTerminal: () => Terminal | null,
  _sessionId: Ref<string>,
) {
  const state = ref<CommandLineState>({
    command: "",
    cursorPos: 0,
    atPrompt: false,
    lastUpdated: 0,
  });
  const terminalMode = ref<TerminalMode>("unknown");

  let onDataDisposable: IDisposable | null = null;
  let onWriteParsedDisposable: IDisposable | null = null;
  let userTyping = false;
  let typingTimer: ReturnType<typeof setTimeout> | null = null;

  /** Extracts the command portion from a terminal line by stripping the prompt. */
  function extractCommand(line: string): { command: string; promptEnd: number } | null {
    // Scan from the end to find the last prompt pattern
    for (const re of PROMPT_ENDINGS) {
      const match = re.exec(line);
      if (match) {
        const promptEnd = match.index + match[0].length;
        return { command: line.slice(promptEnd), promptEnd };
      }
    }
    return null;
  }

  /** Reads the current command from the terminal buffer. */
  function readFromBuffer() {
    const terminal = getTerminal();
    if (!terminal) return;

    // Detect alternate screen (vim, less, htop)
    if (terminal.buffer.active.type === "alternate") {
      terminalMode.value = "alternate";
      state.value = { command: "", cursorPos: 0, atPrompt: false, lastUpdated: Date.now() };
      return;
    }

    const cursorY = terminal.buffer.active.cursorY;
    const cursorX = terminal.buffer.active.cursorX;
    const line = terminal.buffer.active.getLine(cursorY);
    if (!line) return;

    const lineText = line.translateToString(true);

    // Check for reverse-i-search
    if (REVERSE_SEARCH_RE.test(lineText)) {
      state.value = { command: "", cursorPos: 0, atPrompt: false, lastUpdated: Date.now() };
      return;
    }

    const extracted = extractCommand(lineText);
    if (extracted) {
      terminalMode.value = "shell";
      const cmd = extracted.command;
      const cursorInCmd = Math.max(0, cursorX - extracted.promptEnd);
      state.value = {
        command: cmd,
        cursorPos: cursorInCmd,
        atPrompt: true,
        lastUpdated: Date.now(),
      };
    } else {
      // No prompt found — likely command is running or prompt is non-standard
      if (terminalMode.value !== "alternate") {
        terminalMode.value = userTyping ? "shell" : "running";
      }
      state.value = {
        command: "",
        cursorPos: 0,
        atPrompt: false,
        lastUpdated: Date.now(),
      };
    }
  }

  /** Initialize tracking: attach terminal event listeners. */
  function init() {
    const terminal = getTerminal();
    if (!terminal) return;

    // Track user input for mode detection
    onDataDisposable = terminal.onData((data) => {
      userTyping = true;
      if (typingTimer) clearTimeout(typingTimer);
      typingTimer = setTimeout(() => { userTyping = false; }, 500);

      if (data === "\r" || data === "\n") {
        // Enter pressed — command submitted
        terminalMode.value = "running";
        state.value = { command: "", cursorPos: 0, atPrompt: false, lastUpdated: Date.now() };
      } else if (data === "\x03") {
        // Ctrl+C — cancel
        state.value = { command: "", cursorPos: 0, atPrompt: false, lastUpdated: Date.now() };
      }
    });

    // After remote echo, re-read buffer to get actual command state
    onWriteParsedDisposable = terminal.onWriteParsed(() => {
      readFromBuffer();
    });

    // Initial read
    readFromBuffer();
  }

  /** Clean up event listeners. */
  function dispose() {
    onDataDisposable?.dispose();
    onWriteParsedDisposable?.dispose();
    onDataDisposable = null;
    onWriteParsedDisposable = null;
    if (typingTimer) clearTimeout(typingTimer);
  }

  return { state, terminalMode, init, dispose };
}
