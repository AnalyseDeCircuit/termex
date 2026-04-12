import { ref, type Ref } from "vue";
import type { Terminal } from "@xterm/xterm";

export interface DetectedError {
  command: string;
  errorOutput: string;
  matchedPattern: string;
  severity: "info" | "warning" | "critical";
  detectedAt: string;
}

const ERROR_PATTERNS: Array<{
  pattern: RegExp;
  severity: DetectedError["severity"];
  label: string;
}> = [
  // Critical
  { pattern: /No space left on device/i, severity: "critical", label: "disk_full" },
  { pattern: /Read-only file system/i, severity: "critical", label: "readonly_fs" },
  { pattern: /Segmentation fault/i, severity: "critical", label: "segfault" },
  { pattern: /kernel panic/i, severity: "critical", label: "kernel_panic" },
  { pattern: /Out of memory/i, severity: "critical", label: "oom" },
  { pattern: /FATAL/i, severity: "critical", label: "fatal" },

  // Warning
  { pattern: /command not found/i, severity: "warning", label: "cmd_not_found" },
  { pattern: /Permission denied/i, severity: "warning", label: "permission_denied" },
  { pattern: /No such file or directory/i, severity: "warning", label: "no_such_file" },
  { pattern: /Connection refused/i, severity: "warning", label: "conn_refused" },
  { pattern: /Connection timed out/i, severity: "warning", label: "conn_timeout" },
  { pattern: /Name or service not known/i, severity: "warning", label: "dns_fail" },
  { pattern: /Could not resolve hostname/i, severity: "warning", label: "dns_fail" },
  { pattern: /Authentication failure/i, severity: "warning", label: "auth_fail" },
  { pattern: /E:\s+Unable to/i, severity: "warning", label: "apt_error" },
  { pattern: /Failed to start/i, severity: "warning", label: "service_fail" },
  { pattern: /Unit .+ not found/i, severity: "warning", label: "unit_not_found" },
  { pattern: /nginx: \[emerg\]/i, severity: "warning", label: "nginx_error" },
  { pattern: /ERROR \d{4}/i, severity: "warning", label: "mysql_error" },
  { pattern: /Cannot allocate memory/i, severity: "warning", label: "memory" },
  { pattern: /Too many open files/i, severity: "warning", label: "fd_limit" },
  { pattern: /Address already in use/i, severity: "warning", label: "port_in_use" },

  // Info
  { pattern: /failed\b/i, severity: "info", label: "generic_failed" },
];

export function useErrorDetection(
  getTerminal: () => Terminal | null,
  sessionId: Ref<string>,
) {
  const lastError = ref<DetectedError | null>(null);
  const autodiagnoseEnabled = ref(true);
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;
  let disposeHook: (() => void) | null = null;

  function checkForErrors(): void {
    const terminal = getTerminal();
    if (!terminal) return;

    const output = extractRecentLines(terminal, 20);
    if (!output) return;

    for (const { pattern, severity, label } of ERROR_PATTERNS) {
      if (pattern.test(output)) {
        const error: DetectedError = {
          command: "",
          errorOutput: output,
          matchedPattern: label,
          severity,
          detectedAt: new Date().toISOString(),
        };
        lastError.value = error;

        if (autodiagnoseEnabled.value) {
          window.dispatchEvent(
            new CustomEvent("termex:error-detected", {
              detail: { sessionId: sessionId.value, error },
            }),
          );
        }
        break;
      }
    }
  }

  function init(): void {
    const terminal = getTerminal();
    if (!terminal) return;

    disposeHook = terminal.onWriteParsed(() => {
      if (debounceTimer) clearTimeout(debounceTimer);
      debounceTimer = setTimeout(checkForErrors, 500);
    }).dispose;
  }

  function dispose(): void {
    if (debounceTimer) clearTimeout(debounceTimer);
    if (disposeHook) disposeHook();
  }

  return { lastError, autodiagnoseEnabled, init, dispose };
}

function extractRecentLines(terminal: Terminal, count: number): string {
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
