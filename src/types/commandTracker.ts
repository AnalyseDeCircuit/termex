/** Command line tracking state for AI autocomplete. */
export interface CommandLineState {
  /** Current command text (after prompt stripped). */
  command: string;
  /** Cursor position within the command (0-based). */
  cursorPos: number;
  /** Whether the shell is at a prompt (user can input commands). */
  atPrompt: boolean;
  /** Last update timestamp (for debounce). */
  lastUpdated: number;
}

/** Terminal display mode. */
export type TerminalMode =
  | "shell"      // At shell prompt, user can input commands
  | "running"    // Command is executing (output streaming)
  | "alternate"  // Alternate screen buffer (vim/less/htop)
  | "unknown";   // Initial state
