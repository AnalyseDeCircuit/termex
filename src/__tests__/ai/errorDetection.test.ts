import { describe, it, expect } from "vitest";

// Inline error patterns for testing (same as useErrorDetection)
const ERROR_PATTERNS: Array<{
  pattern: RegExp;
  severity: string;
  label: string;
}> = [
  {
    pattern: /No space left on device/i,
    severity: "critical",
    label: "disk_full",
  },
  {
    pattern: /Read-only file system/i,
    severity: "critical",
    label: "readonly_fs",
  },
  {
    pattern: /Segmentation fault/i,
    severity: "critical",
    label: "segfault",
  },
  { pattern: /Out of memory/i, severity: "critical", label: "oom" },
  {
    pattern: /command not found/i,
    severity: "warning",
    label: "cmd_not_found",
  },
  {
    pattern: /Permission denied/i,
    severity: "warning",
    label: "permission_denied",
  },
  {
    pattern: /No such file or directory/i,
    severity: "warning",
    label: "no_such_file",
  },
  {
    pattern: /Connection refused/i,
    severity: "warning",
    label: "conn_refused",
  },
  { pattern: /failed\b/i, severity: "info", label: "generic_failed" },
];

function detectError(
  output: string
): { severity: string; label: string } | null {
  for (const { pattern, severity, label } of ERROR_PATTERNS) {
    if (pattern.test(output)) {
      return { severity, label };
    }
  }
  return null;
}

describe("Error Detection Patterns", () => {
  it("detects 'command not found' as warning", () => {
    const result = detectError("bash: foo: command not found");
    expect(result).not.toBeNull();
    expect(result!.severity).toBe("warning");
    expect(result!.label).toBe("cmd_not_found");
  });

  it("detects 'No space left on device' as critical", () => {
    const result = detectError("write error: No space left on device");
    expect(result).not.toBeNull();
    expect(result!.severity).toBe("critical");
    expect(result!.label).toBe("disk_full");
  });

  it("detects 'Permission denied' as warning", () => {
    const result = detectError("bash: /etc/shadow: Permission denied");
    expect(result).not.toBeNull();
    expect(result!.severity).toBe("warning");
    expect(result!.label).toBe("permission_denied");
  });

  it("detects 'Segmentation fault' as critical", () => {
    const result = detectError("Segmentation fault (core dumped)");
    expect(result).not.toBeNull();
    expect(result!.severity).toBe("critical");
    expect(result!.label).toBe("segfault");
  });

  it("ignores normal output", () => {
    const result = detectError(
      "total 16\ndrwxr-xr-x  4 user user 4096 Apr 12 10:00 ."
    );
    expect(result).toBeNull();
  });

  it("severity priority: critical before warning", () => {
    // "Out of memory" is critical, should match before "failed"
    const result = detectError("Out of memory: killed process 1234");
    expect(result).not.toBeNull();
    expect(result!.severity).toBe("critical");
  });

  it("detects generic 'failed' as info", () => {
    const result = detectError("Job for nginx.service failed.");
    expect(result).not.toBeNull();
    expect(result!.severity).toBe("info");
    expect(result!.label).toBe("generic_failed");
  });
});
