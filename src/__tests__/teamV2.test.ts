import { describe, it, expect, beforeEach, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";

vi.mock("@/utils/tauri", () => ({
  tauriInvoke: vi.fn(),
  tauriListen: vi.fn(() => Promise.resolve(() => {})),
}));

import { useTeamStore } from "@/stores/teamStore";
import { useTeamPermission } from "@/composables/useTeamPermission";
import type { Capability } from "@/types/team";

describe("useTeamPermission composable", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("returns true for all capabilities when not in a team", () => {
    const store = useTeamStore();
    store.status.joined = false;
    const { can } = useTeamPermission();

    expect(can("ServerConnect")).toBe(true);
    expect(can("ServerDelete")).toBe(true);
    expect(can("TeamRemove")).toBe(true);
    expect(can("AuditExport")).toBe(true);
  });

  it("checks capabilities from store when in a team", () => {
    const store = useTeamStore();
    store.status.joined = true;
    store.status.role = "developer";
    store.myCapabilities = ["ServerConnect", "SnippetExecute", "SyncPull"];

    const { can } = useTeamPermission();

    expect(can("ServerConnect")).toBe(true);
    expect(can("SnippetExecute")).toBe(true);
    expect(can("SyncPull")).toBe(true);
    expect(can("ServerEdit")).toBe(false);
    expect(can("ServerDelete")).toBe(false);
    expect(can("TeamRemove")).toBe(false);
  });

  it("admin has all capabilities", () => {
    const store = useTeamStore();
    store.status.joined = true;
    store.status.role = "admin";
    store.myCapabilities = [
      "ServerConnect", "ServerCreate", "ServerEdit", "ServerDelete",
      "ServerViewCredentials", "SnippetCreate", "SnippetEdit", "SnippetDelete",
      "SnippetExecute", "TeamInvite", "TeamRemove", "TeamRoleAssign",
      "TeamSettingsEdit", "SyncPush", "SyncPull", "AuditView", "AuditExport",
    ];

    const { can } = useTeamPermission();

    expect(can("ServerDelete")).toBe(true);
    expect(can("TeamRemove")).toBe(true);
    expect(can("AuditExport")).toBe(true);
  });

  it("developer can execute snippets but not create/edit/delete", () => {
    const store = useTeamStore();
    store.status.joined = true;
    store.status.role = "developer";
    store.myCapabilities = ["ServerConnect", "SnippetExecute", "SyncPull"];

    const { can } = useTeamPermission();

    expect(can("SnippetExecute")).toBe(true);
    expect(can("SnippetCreate")).toBe(false);
    expect(can("SnippetEdit")).toBe(false);
    expect(can("SnippetDelete")).toBe(false);
  });

  it("viewer has minimal capabilities", () => {
    const store = useTeamStore();
    store.status.joined = true;
    store.status.role = "viewer";
    store.myCapabilities = ["SyncPull", "AuditView"];

    const { can } = useTeamPermission();

    expect(can("SyncPull")).toBe(true);
    expect(can("AuditView")).toBe(true);
    expect(can("ServerConnect")).toBe(false);
    expect(can("SnippetExecute")).toBe(false);
  });
});

describe("teamStore canPush computed", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("canPush is true when SyncPush is in capabilities", () => {
    const store = useTeamStore();
    store.myCapabilities = ["SyncPush", "SyncPull"];
    expect(store.canPush).toBe(true);
  });

  it("canPush is false without SyncPush", () => {
    const store = useTeamStore();
    store.myCapabilities = ["SyncPull"];
    expect(store.canPush).toBe(false);
  });

  it("canPush is false with empty capabilities", () => {
    const store = useTeamStore();
    store.myCapabilities = [];
    expect(store.canPush).toBe(false);
  });
});

describe("Capability type", () => {
  it("all expected capabilities are valid types", () => {
    const allCaps: Capability[] = [
      "ServerConnect", "ServerCreate", "ServerEdit", "ServerDelete",
      "ServerViewCredentials", "SnippetCreate", "SnippetEdit", "SnippetDelete",
      "SnippetExecute", "TeamInvite", "TeamRemove", "TeamRoleAssign",
      "TeamSettingsEdit", "SyncPush", "SyncPull", "AuditView", "AuditExport",
    ];
    expect(allCaps).toHaveLength(17);
  });
});
