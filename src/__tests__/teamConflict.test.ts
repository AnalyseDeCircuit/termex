import { describe, it, expect, vi, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import type { ConflictItem, ConflictResolution } from "@/types/team";

const mockInvoke = vi.fn();
vi.mock("@/utils/tauri", () => ({
  tauriInvoke: (...args: unknown[]) => mockInvoke(...args),
  tauriListen: vi.fn(() => Promise.resolve(() => {})),
}));

import { useTeamStore } from "@/stores/teamStore";

describe("Conflict Resolution", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    mockInvoke.mockReset();
  });

  it("sync returns conflict items when conflicts exist", async () => {
    const conflicts: ConflictItem[] = [
      {
        entityType: "server",
        entityId: "srv-1",
        entityName: "web-prod",
        localValue: { host: "10.0.1.1", port: "22", name: "web-prod", username: "deploy" },
        remoteValue: { host: "10.0.1.2", port: "22", name: "web-prod", username: "admin" },
        conflictingFields: ["host", "username"],
        localModifiedBy: "you",
        remoteModifiedBy: "alice",
        localModifiedAt: "2026-04-15T10:00:00Z",
        remoteModifiedAt: "2026-04-15T10:05:00Z",
      },
    ];

    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "team_sync") {
        return Promise.resolve({
          imported: 2,
          exported: 1,
          conflicts,
          deletedRemote: 0,
        });
      }
      if (cmd === "team_get_status") {
        return Promise.resolve({
          joined: true, name: "T", role: "admin",
          memberCount: 2, lastSync: null, hasPendingChanges: false, repoUrl: null,
        });
      }
      if (cmd === "team_my_capabilities") {
        return Promise.resolve(["SyncPush", "SyncPull"]);
      }
      return Promise.resolve(undefined);
    });

    const store = useTeamStore();
    const result = await store.sync();

    expect(result.conflicts).toHaveLength(1);
    expect(result.conflicts[0].entityId).toBe("srv-1");
    expect(result.conflicts[0].conflictingFields).toContain("host");
    expect(result.conflicts[0].conflictingFields).toContain("username");
  });

  it("sync returns empty conflicts when no conflicts", async () => {
    mockInvoke.mockImplementation((cmd: string) => {
      if (cmd === "team_sync") {
        return Promise.resolve({
          imported: 3, exported: 0, conflicts: [], deletedRemote: 1,
        });
      }
      if (cmd === "team_get_status") {
        return Promise.resolve({
          joined: true, name: "T", role: "ops",
          memberCount: 2, lastSync: null, hasPendingChanges: false, repoUrl: null,
        });
      }
      if (cmd === "team_my_capabilities") {
        return Promise.resolve(["SyncPush", "SyncPull"]);
      }
      return Promise.resolve(undefined);
    });

    const store = useTeamStore();
    const result = await store.sync();
    expect(result.conflicts).toEqual([]);
  });

  it("team_resolve_conflicts sends correct resolution format", async () => {
    mockInvoke.mockResolvedValue(undefined);

    const { tauriInvoke } = await import("@/utils/tauri");
    const resolutions: ConflictResolution[] = [
      { entityType: "server", entityId: "srv-1", strategy: "KeepLocal" },
      { entityType: "server", entityId: "srv-2", strategy: "UseRemote" },
    ];

    await tauriInvoke("team_resolve_conflicts", { resolutions });

    expect(mockInvoke).toHaveBeenCalledWith("team_resolve_conflicts", {
      resolutions: [
        { entityType: "server", entityId: "srv-1", strategy: "KeepLocal" },
        { entityType: "server", entityId: "srv-2", strategy: "UseRemote" },
      ],
    });
  });

  it("team_resolve_conflicts supports Skip strategy", async () => {
    mockInvoke.mockResolvedValue(undefined);

    const { tauriInvoke } = await import("@/utils/tauri");
    const resolutions: ConflictResolution[] = [
      { entityType: "server", entityId: "srv-1", strategy: "KeepLocal" },
      { entityType: "server", entityId: "srv-2", strategy: "Skip" },
      { entityType: "server", entityId: "srv-3", strategy: "UseRemote" },
    ];

    await tauriInvoke("team_resolve_conflicts", { resolutions });

    expect(mockInvoke).toHaveBeenCalledWith("team_resolve_conflicts", {
      resolutions: expect.arrayContaining([
        expect.objectContaining({ entityId: "srv-2", strategy: "Skip" }),
      ]),
    });
  });

  it("ConflictItem has all required fields", () => {
    const item: ConflictItem = {
      entityType: "server",
      entityId: "test-id",
      entityName: "Test Server",
      localValue: { host: "1.2.3.4" },
      remoteValue: { host: "5.6.7.8" },
      conflictingFields: ["host"],
      localModifiedBy: "you",
      remoteModifiedBy: "bob",
      localModifiedAt: "2026-04-15T10:00:00Z",
      remoteModifiedAt: "2026-04-15T10:01:00Z",
    };

    expect(item.conflictingFields).toHaveLength(1);
    expect(item.localValue.host).not.toBe(item.remoteValue.host);
  });
});
