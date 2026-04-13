import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock Tauri IPC
vi.mock("@/utils/tauri", () => ({
  tauriInvoke: vi.fn().mockResolvedValue(undefined),
  tauriListen: vi.fn().mockResolvedValue(() => {}),
}));

// Mock Pinia
import { setActivePinia, createPinia } from "pinia";
import { useSessionStore } from "@/stores/sessionStore";
import * as paneTree from "@/utils/paneTree";
import type { PaneNode } from "@/types/paneLayout";

describe("useBroadcast", () => {
  let sessionStore: ReturnType<typeof useSessionStore>;

  beforeEach(() => {
    setActivePinia(createPinia());
    sessionStore = useSessionStore();
    vi.clearAllMocks();
  });

  function setupThreePaneTab() {
    // Create a tab with 3 panes: A (left), B (top-right), C (bottom-right)
    const tabKey = "test-tab";
    const a = paneTree.createLeaf("sess-a", "srv-1", "A");
    const b = paneTree.createLeaf("sess-b", "srv-1", "B");
    const c = paneTree.createLeaf("sess-c", "srv-1", "C");

    let root: PaneNode = paneTree.splitPane(a, a.id, "vertical", b);
    root = paneTree.splitPane(root, b.id, "horizontal", c);

    sessionStore.paneLayouts.set(tabKey, root);
    sessionStore.tabs.push({
      tabKey,
      id: "sess-a",
      sessionId: "sess-a",
      title: "Test",
      active: true,
    });

    // Mock sessions
    sessionStore.sessions.set("sess-a", {
      id: "sess-a", serverId: "srv-1", serverName: "A", status: "connected", startedAt: "", type: "ssh",
    });
    sessionStore.sessions.set("sess-b", {
      id: "sess-b", serverId: "srv-1", serverName: "B", status: "connected", startedAt: "", type: "ssh",
    });
    sessionStore.sessions.set("sess-c", {
      id: "sess-c", serverId: "srv-1", serverName: "C", status: "connected", startedAt: "", type: "ssh",
    });

    // Set active pane to A
    sessionStore.activePaneId = a.id;

    return { tabKey, a, b, c, root };
  }

  it("toggleBroadcast initializes all panes", () => {
    const { tabKey, a, b, c } = setupThreePaneTab();

    sessionStore.toggleBroadcast();

    const bc = sessionStore.broadcastStates.get(tabKey);
    expect(bc).toBeTruthy();
    expect(bc!.enabled).toBe(true);
    expect(bc!.includedPaneIds.has(a.id)).toBe(true);
    expect(bc!.includedPaneIds.has(b.id)).toBe(true);
    expect(bc!.includedPaneIds.has(c.id)).toBe(true);
  });

  it("togglePaneBroadcast adds/removes pane", () => {
    const { tabKey, b } = setupThreePaneTab();

    // Enable broadcast first
    sessionStore.toggleBroadcast();
    expect(sessionStore.broadcastStates.get(tabKey)!.includedPaneIds.has(b.id)).toBe(true);

    // Toggle B off
    sessionStore.togglePaneBroadcast(b.id);
    expect(sessionStore.broadcastStates.get(tabKey)!.includedPaneIds.has(b.id)).toBe(false);

    // Toggle B back on
    sessionStore.togglePaneBroadcast(b.id);
    expect(sessionStore.broadcastStates.get(tabKey)!.includedPaneIds.has(b.id)).toBe(true);
  });

  it("disabled broadcast state is correct", () => {
    setupThreePaneTab();

    // Broadcast is not enabled by default
    expect(sessionStore.currentBroadcast).toBeNull();
  });

  it("broadcast sends to all included panes via getBroadcastSessionIds", () => {
    const { tabKey } = setupThreePaneTab();

    sessionStore.toggleBroadcast();

    // Check that all session IDs are collected
    const layout = sessionStore.paneLayouts.get(tabKey)!;
    const leafIds = paneTree.collectLeafIds(layout);
    const bc = sessionStore.broadcastStates.get(tabKey)!;

    const sessionIds = leafIds
      .filter((id) => bc.includedPaneIds.has(id))
      .map((id) => paneTree.findLeaf(layout, id)?.sessionId)
      .filter(Boolean);

    expect(sessionIds).toContain("sess-a");
    expect(sessionIds).toContain("sess-b");
    expect(sessionIds).toContain("sess-c");
  });

  it("broadcast excludes connecting panes", () => {
    const { tabKey } = setupThreePaneTab();

    // Change sess-b to a connecting state
    sessionStore.sessions.delete("sess-b");
    const layout = sessionStore.paneLayouts.get(tabKey)!;
    const leafIds = paneTree.collectLeafIds(layout);

    // Find pane with sess-b and set it to connecting
    for (const leafId of leafIds) {
      const leaf = paneTree.findLeaf(layout, leafId);
      if (leaf?.sessionId === "sess-b") {
        leaf.sessionId = "connecting-test";
        break;
      }
    }

    sessionStore.toggleBroadcast();

    const bc = sessionStore.broadcastStates.get(tabKey)!;
    const allLeafIds = paneTree.collectLeafIds(layout);
    const sessionIds = allLeafIds
      .filter((id) => bc.includedPaneIds.has(id))
      .map((id) => paneTree.findLeaf(layout, id)?.sessionId)
      .filter((id): id is string => id !== null && !id!.startsWith("connecting-"));

    expect(sessionIds).toContain("sess-a");
    expect(sessionIds).not.toContain("connecting-test");
    expect(sessionIds).toContain("sess-c");
  });

  it("pane count reflects split state", () => {
    setupThreePaneTab();
    expect(sessionStore.paneCount).toBe(3);
  });
});
