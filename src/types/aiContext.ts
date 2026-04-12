/** Terminal context automatically collected for AI conversations. */
export interface TerminalContext {
  server: {
    hostname: string;
    os: string;
    username: string;
    connectionChain: string;
  };
  shell: {
    cwd: string;
    lastCommand: string;
    lastExitCode: number | null;
    terminalMode: string;
  };
  recentOutput: string;
  capturedAt: string;
}

export interface ContextOptions {
  includeOutput: boolean;
  outputLines: number;
  includeServer: boolean;
  includeShell: boolean;
}

export const DEFAULT_CONTEXT_OPTIONS: ContextOptions = {
  includeOutput: true,
  outputLines: 50,
  includeServer: true,
  includeShell: true,
};

/** Monitor alert for AI analysis. */
export interface MonitorAlert {
  metric: "cpu" | "memory" | "disk" | "load";
  value: number;
  threshold: number;
  topProcesses?: string[];
  timestamp: string;
}
