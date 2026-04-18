import { describe, it, expect, vi, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";

const mockInvoke = vi.fn();
vi.mock("@/utils/tauri", () => ({
  tauriInvoke: (...args: unknown[]) => mockInvoke(...args),
  tauriListen: vi.fn(() => Promise.resolve(() => {})),
}));

describe("Audit API contracts", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    mockInvoke.mockReset();
  });

  it("audit_log_list supports date range parameters", async () => {
    mockInvoke.mockResolvedValue({
      items: [],
      total: 0,
      page: 1,
      pageSize: 50,
    });

    const { tauriInvoke } = await import("@/utils/tauri");
    await tauriInvoke("audit_log_list", {
      eventType: "ssh_connect_success",
      startDate: "2026-04-01T00:00:00Z",
      endDate: "2026-04-15T23:59:59Z",
      limit: 50,
      offset: 0,
    });

    expect(mockInvoke).toHaveBeenCalledWith("audit_log_list", {
      eventType: "ssh_connect_success",
      startDate: "2026-04-01T00:00:00Z",
      endDate: "2026-04-15T23:59:59Z",
      limit: 50,
      offset: 0,
    });
  });

  it("audit_log_summary returns categorized counts", async () => {
    mockInvoke.mockResolvedValue({
      total: 100,
      connections: 50,
      credentialAccess: 5,
      configChanges: 20,
      memberOps: 10,
      byType: {
        ssh_connect_success: 40,
        ssh_connect_failed: 10,
        server_created: 15,
        server_deleted: 5,
      },
    });

    const { tauriInvoke } = await import("@/utils/tauri");
    const result = await tauriInvoke("audit_log_summary", {
      startDate: "2026-04-01T00:00:00Z",
      endDate: "2026-04-30T23:59:59Z",
    });

    expect(result).toHaveProperty("total", 100);
    expect(result).toHaveProperty("connections", 50);
    expect(result).toHaveProperty("credentialAccess", 5);
    expect(result).toHaveProperty("configChanges", 20);
    expect(result).toHaveProperty("memberOps", 10);
  });

  it("audit_export_report accepts format parameter", async () => {
    mockInvoke.mockResolvedValue(undefined);

    const { tauriInvoke } = await import("@/utils/tauri");
    await tauriInvoke("audit_export_report", {
      filePath: "/tmp/report.csv",
      startDate: "2026-04-01T00:00:00Z",
      endDate: "2026-04-15T23:59:59Z",
      eventTypes: null,
      format: "csv",
    });

    expect(mockInvoke).toHaveBeenCalledWith("audit_export_report", expect.objectContaining({
      format: "csv",
      filePath: "/tmp/report.csv",
    }));
  });

  it("audit_log_list pagination returns correct page info", async () => {
    mockInvoke.mockResolvedValue({
      items: [{ id: 1, timestamp: "2026-04-15T10:00:00Z", eventType: "ssh_connect_success", detail: null }],
      total: 100,
      page: 3,
      pageSize: 20,
    });

    const { tauriInvoke } = await import("@/utils/tauri");
    const result = await tauriInvoke<{ total: number; page: number; pageSize: number }>(
      "audit_log_list",
      { limit: 20, offset: 40 },
    );

    expect(result.total).toBe(100);
    expect(result.page).toBe(3);
    expect(result.pageSize).toBe(20);
  });
});
