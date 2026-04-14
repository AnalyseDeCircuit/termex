import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { tauriInvoke } from "@/utils/tauri";
import type { Session, SessionStatus, Tab, CloudMeta } from "@/types/session";
import type { PaneNode, BroadcastState } from "@/types/paneLayout";
import * as paneTree from "@/utils/paneTree";

export const useSessionStore = defineStore("session", () => {
  // ── State ──────────────────────────────────────────────────

  const sessions = ref<Map<string, Session>>(new Map());
  const tabs = ref<Tab[]>([]);
  /** Session IDs being deliberately disconnected by the user (not auto-reconnect). */
  const deliberateDisconnects = ref<Set<string>>(new Set());

  // ── Pane state ────────────────────────────────────────────

  /** Pane layout tree per tab, keyed by tabKey. */
  const paneLayouts = ref<Map<string, PaneNode>>(new Map());
  /** Currently focused pane ID. */
  const activePaneId = ref<string | null>(null);
  /** Broadcast state per tab, keyed by tabKey. */
  const broadcastStates = ref<Map<string, BroadcastState>>(new Map());

  // ── Getters ────────────────────────────────────────────────

  /** Active session ID derived from activePaneId → leaf → sessionId. */
  const activeSessionId = computed(() => {
    if (!activePaneId.value) return null;
    const tab = activeTab.value;
    if (!tab) return null;
    const layout = paneLayouts.value.get(tab.tabKey);
    if (!layout) return null;
    const leaf = paneTree.findLeaf(layout, activePaneId.value);
    return leaf?.sessionId ?? null;
  });

  const activeSession = computed(() => {
    if (!activeSessionId.value) return null;
    return sessions.value.get(activeSessionId.value) ?? null;
  });

  const activeTab = computed(() => {
    if (!activePaneId.value) return null;
    // Find which tab's layout contains the active pane
    for (const tab of tabs.value) {
      const layout = paneLayouts.value.get(tab.tabKey);
      if (layout && paneTree.findLeaf(layout, activePaneId.value)) {
        return tab;
      }
    }
    return null;
  });

  const currentPaneLayout = computed(() => {
    const tab = activeTab.value;
    return tab ? paneLayouts.value.get(tab.tabKey) ?? null : null;
  });

  const currentBroadcast = computed(() => {
    const tab = activeTab.value;
    return tab ? broadcastStates.value.get(tab.tabKey) ?? null : null;
  });

  const paneCount = computed(() => {
    const layout = currentPaneLayout.value;
    return layout ? paneTree.countLeaves(layout) : 0;
  });

  // ── Actions ────────────────────────────────────────────────

  /** Opens an SSH connection (authenticate only) and creates a tab immediately.
   *  Shell is opened later by useTerminal after the terminal UI is mounted. */
  async function connect(
    serverId: string,
    serverName: string,
  ): Promise<void> {
    // 1. Create tab + session immediately so user sees feedback
    const tabKey = `tab-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
    const placeholderId = `connecting-${tabKey}`;

    const session: Session = {
      id: placeholderId,
      serverId,
      serverName,
      status: "connecting",
      startedAt: new Date().toISOString(),
      type: "ssh",
    };
    sessions.value.set(placeholderId, session);

    const tab: Tab = {
      tabKey,
      id: placeholderId,
      sessionId: placeholderId,
      title: serverName,
      active: true,
    };
    tabs.value.forEach((t) => (t.active = false));
    tabs.value.push(tab);

    // Initialize single-pane layout
    const initialLeaf = paneTree.createLeaf(placeholderId, serverId, serverName);
    paneLayouts.value.set(tabKey, initialLeaf);
    activePaneId.value = initialLeaf.id;

    // 2. Attempt SSH connection (authenticate only, no shell yet)
    try {
      const realId = await tauriInvoke<string>("ssh_connect", {
        serverId,
      });

      // 3. Success — replace placeholder with real session
      sessions.value.delete(placeholderId);
      tab.id = realId;
      tab.sessionId = realId;

      const realSession: Session = {
        id: realId,
        serverId,
        serverName,
        status: "authenticated",
        startedAt: session.startedAt,
        type: "ssh",
      };
      sessions.value.set(realId, realSession);

      // Update pane's sessionId
      updatePaneSessionId(tabKey, initialLeaf.id, realId);
    } catch (err) {
      // 4. Failed — update placeholder session to error
      const s = sessions.value.get(placeholderId);
      if (s) {
        s.status = "error";
      }
      throw err;
    }
  }

  /** Opens a local terminal tab (PTY, not SSH). */
  function openLocalTerminal(): string {
    const tabKey = `tab-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
    const sessionId = `local-${tabKey}`;

    const session: Session = {
      id: sessionId,
      serverId: "",
      serverName: "Local Terminal",
      status: "connected",
      startedAt: new Date().toISOString(),
      type: "local",
    };
    sessions.value.set(sessionId, session);

    const tab: Tab = {
      tabKey,
      id: sessionId,
      sessionId,
      title: "Local",
      active: true,
    };
    tabs.value.forEach((t) => (t.active = false));
    tabs.value.push(tab);

    // Initialize single-pane layout
    const initialLeaf = paneTree.createLeaf(sessionId, "", "Local");
    paneLayouts.value.set(tabKey, initialLeaf);
    activePaneId.value = initialLeaf.id;

    return sessionId;
  }

  /** Opens the shell channel with actual terminal dimensions.
   *  Called by useTerminal after fitAddon calculates real cols/rows. */
  async function openShell(
    sessionId: string,
    cols: number,
    rows: number,
  ): Promise<void> {
    await tauriInvoke("ssh_open_shell", { sessionId, cols, rows });
    const session = sessions.value.get(sessionId);
    if (session) {
      session.status = "connected";
    }
  }

  /** Disconnects a session (SSH or local PTY) and removes the tab. */
  async function disconnect(sessionId: string): Promise<void> {
    // For placeholder sessions that never connected, just remove the tab
    if (sessionId.startsWith("connecting-")) {
      // Find tab by sessionId and close it
      const tab = tabs.value.find((t) => t.sessionId === sessionId);
      if (tab) closeTabByKey(tab.tabKey);
      return;
    }

    // Mark as deliberate so auto-reconnect does not trigger
    deliberateDisconnects.value.add(sessionId);

    // Clean up monitor state
    try {
      const { useMonitorStore } = await import("@/stores/monitorStore");
      useMonitorStore().cleanup(sessionId);
    } catch { /* ignore if monitor store not available */ }

    const session = sessions.value.get(sessionId);
    const sessionType = session?.type ?? (sessionId.startsWith("local-") ? "local" : "ssh");

    try {
      if (sessionType === "local" || sessionType === "kube-exec" || sessionType === "ssm") {
        await tauriInvoke("local_pty_close", { sessionId });
      } else if (sessionType === "kube-logs") {
        await tauriInvoke("cloud_kube_logs_stop", { sessionId });
      } else {
        await tauriInvoke("ssh_disconnect", { sessionId });
      }
    } catch { /* ignore */ }

    // Find tab containing this session and close it
    const tab = tabs.value.find((t) => t.sessionId === sessionId);
    if (tab) closeTabByKey(tab.tabKey);
    deliberateDisconnects.value.delete(sessionId);
  }

  /** Returns true if the session is being deliberately disconnected by user action. */
  function isDeliberateDisconnect(sessionId: string): boolean {
    return deliberateDisconnects.value.has(sessionId);
  }

  /** Reconnects a disconnected SSH session in-place.
   *  The old session entry is replaced with the new one; the tab stays and terminal buffer is preserved. */
  async function reconnectSession(
    oldSessionId: string,
    newSessionId: string,
    cols: number,
    rows: number,
  ): Promise<void> {
    const oldSession = sessions.value.get(oldSessionId);
    if (!oldSession) return;

    // Clean up old session's monitor state
    try {
      const { useMonitorStore } = await import("@/stores/monitorStore");
      useMonitorStore().cleanup(oldSessionId);
    } catch { /* ignore */ }

    const { serverId, serverName, startedAt } = oldSession;

    // Replace session entry
    sessions.value.delete(oldSessionId);
    sessions.value.set(newSessionId, {
      id: newSessionId,
      serverId,
      serverName,
      status: "authenticated",
      startedAt,
      type: "ssh",
    });

    // Update tab to point to new session (triggers TerminalView watcher → rebindSession)
    const tab = tabs.value.find((t) => t.sessionId === oldSessionId);
    if (tab) {
      tab.sessionId = newSessionId;
      tab.id = newSessionId;

      // Update pane layout sessionId for the pane that owned the old session
      const layout = paneLayouts.value.get(tab.tabKey);
      if (layout) {
        updatePaneSessionIdBySession(tab.tabKey, oldSessionId, newSessionId);
      }
    }

    // Open shell on the new session
    await openShell(newSessionId, cols, rows);
  }

  /** Updates the status of a session. */
  function updateStatus(sessionId: string, status: SessionStatus) {
    const session = sessions.value.get(sessionId);
    if (session) {
      session.status = status;
    }
  }

  /** Sets the active tab by activating a specific pane or the first pane in the tab. */
  function setActive(sessionId: string) {
    tabs.value.forEach((t) => (t.active = t.sessionId === sessionId));

    // Find tab for this sessionId and activate its first pane (or active pane if already in this tab)
    const tab = tabs.value.find((t) => t.sessionId === sessionId);
    if (tab) {
      const layout = paneLayouts.value.get(tab.tabKey);
      if (layout) {
        // Check if current activePaneId is already in this tab
        if (activePaneId.value && paneTree.findLeaf(layout, activePaneId.value)) {
          return; // Already focused on a pane in this tab
        }
        // Otherwise, activate the first leaf
        const leaves = paneTree.collectLeafIds(layout);
        activePaneId.value = leaves[0] ?? null;
      }
    }
  }

  /** Closes a tab by tabKey and cleans up all pane sessions. */
  function closeTabByKey(tabKey: string) {
    const layout = paneLayouts.value.get(tabKey);

    // Disconnect all pane sessions
    if (layout) {
      const leafIds = paneTree.collectLeafIds(layout);
      for (const leafId of leafIds) {
        const leaf = paneTree.findLeaf(layout, leafId);
        if (leaf?.sessionId && !leaf.sessionId.startsWith("connecting-")) {
          sessions.value.delete(leaf.sessionId);
        }
      }
    }

    // Clean up pane state
    paneLayouts.value.delete(tabKey);
    broadcastStates.value.delete(tabKey);

    // Remove tab
    const idx = tabs.value.findIndex((t) => t.tabKey === tabKey);
    if (idx !== -1) {
      tabs.value.splice(idx, 1);
    }

    // Activate the last remaining tab, or clear
    const isActiveTab = activeTab.value?.tabKey === tabKey || !activeTab.value;
    if (isActiveTab) {
      const lastTab = tabs.value[tabs.value.length - 1];
      if (lastTab) {
        const layout = paneLayouts.value.get(lastTab.tabKey);
        if (layout) {
          const leaves = paneTree.collectLeafIds(layout);
          activePaneId.value = leaves[0] ?? null;
        }
        lastTab.active = true;
      } else {
        activePaneId.value = null;
      }
    }
  }

  /** Legacy closeTab — finds tab by sessionId and closes by tabKey. */
  function closeTab(sessionId: string) {
    const tab = tabs.value.find((t) => t.sessionId === sessionId);
    if (tab) {
      closeTabByKey(tab.tabKey);
    } else {
      // Fallback: clean up session directly
      sessions.value.delete(sessionId);
    }
  }

  // ── Pane actions ──────────────────────────────────────────

  /** Updates a pane's sessionId (after SSH connect succeeds). */
  function updatePaneSessionId(tabKey: string, paneId: string, newSessionId: string): void {
    const layout = paneLayouts.value.get(tabKey);
    if (!layout) return;
    const leaf = paneTree.findLeaf(layout, paneId);
    if (leaf) {
      leaf.sessionId = newSessionId;
    }
  }

  /** Updates pane sessionId by finding the pane that has the old sessionId. */
  function updatePaneSessionIdBySession(tabKey: string, oldSessionId: string, newSessionId: string): void {
    const layout = paneLayouts.value.get(tabKey);
    if (!layout) return;
    const leafIds = paneTree.collectLeafIds(layout);
    for (const leafId of leafIds) {
      const leaf = paneTree.findLeaf(layout, leafId);
      if (leaf && leaf.sessionId === oldSessionId) {
        leaf.sessionId = newSessionId;
        break;
      }
    }
  }

  /** Splits the active pane and connects the new pane to the same server. */
  async function splitActivePane(
    direction: "horizontal" | "vertical",
  ): Promise<void> {
    const tab = activeTab.value;
    if (!tab || !activePaneId.value) return;

    const layout = paneLayouts.value.get(tab.tabKey);
    if (!layout) return;

    // Check max depth
    if (paneTree.getTreeDepth(layout) >= 4) {
      return; // Caller should show warning
    }

    const currentLeaf = paneTree.findLeaf(layout, activePaneId.value);
    if (!currentLeaf) return;

    // Create new pane targeting same server
    const newLeaf = paneTree.createLeaf(
      `connecting-${Date.now()}`,
      currentLeaf.serverId,
      currentLeaf.title,
    );

    // Update tree
    const newLayout = paneTree.splitPane(layout, activePaneId.value, direction, newLeaf);
    paneLayouts.value.set(tab.tabKey, newLayout);

    // For local terminals, create a new local PTY
    const currentSession = sessions.value.get(currentLeaf.sessionId);
    if (currentSession?.type === "local") {
      const localTabKey = `tab-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
      const localSessionId = `local-${localTabKey}`;
      const session: Session = {
        id: localSessionId,
        serverId: "",
        serverName: "Local Terminal",
        status: "connected",
        startedAt: new Date().toISOString(),
        type: "local",
      };
      sessions.value.set(localSessionId, session);
      newLeaf.sessionId = localSessionId;
      return;
    }

    // SSH: connect new pane
    try {
      const realId = await tauriInvoke<string>("ssh_connect", {
        serverId: currentLeaf.serverId,
      });
      newLeaf.sessionId = realId;

      const session: Session = {
        id: realId,
        serverId: currentLeaf.serverId,
        serverName: currentLeaf.title,
        status: "authenticated",
        startedAt: new Date().toISOString(),
        type: "ssh",
      };
      sessions.value.set(realId, session);
    } catch {
      // Remove new pane on failure
      const reverted = paneTree.closePane(newLayout, newLeaf.id);
      if (reverted) {
        paneLayouts.value.set(tab.tabKey, reverted);
      }
    }
  }

  /** Closes a specific pane. If it's the last pane, closes the tab. */
  function closePane(paneId: string): void {
    // Find which tab contains this pane
    let targetTabKey: string | null = null;
    for (const tab of tabs.value) {
      const layout = paneLayouts.value.get(tab.tabKey);
      if (layout && paneTree.findLeaf(layout, paneId)) {
        targetTabKey = tab.tabKey;
        break;
      }
    }
    if (!targetTabKey) return;

    const layout = paneLayouts.value.get(targetTabKey);
    if (!layout) return;

    const leaf = paneTree.findLeaf(layout, paneId);
    if (!leaf) return;

    // Disconnect the session
    if (leaf.sessionId && !leaf.sessionId.startsWith("connecting-")) {
      const session = sessions.value.get(leaf.sessionId);
      const sType = session?.type ?? "ssh";
      if (sType === "local" || sType === "kube-exec" || sType === "ssm") {
        tauriInvoke("local_pty_close", { sessionId: leaf.sessionId }).catch(() => {});
      } else if (sType === "kube-logs") {
        tauriInvoke("cloud_kube_logs_stop", { sessionId: leaf.sessionId }).catch(() => {});
      } else {
        tauriInvoke("ssh_disconnect", { sessionId: leaf.sessionId }).catch(() => {});
      }
      sessions.value.delete(leaf.sessionId);
    }

    const newLayout = paneTree.closePane(layout, paneId);
    if (!newLayout) {
      // Last pane — close the entire tab
      closeTabByKey(targetTabKey);
      return;
    }

    paneLayouts.value.set(targetTabKey, newLayout);

    // Move focus to sibling
    if (activePaneId.value === paneId) {
      const leaves = paneTree.collectLeafIds(newLayout);
      activePaneId.value = leaves[0] ?? null;
    }

    // Remove from broadcast includes
    const bc = broadcastStates.value.get(targetTabKey);
    if (bc) {
      bc.includedPaneIds.delete(paneId);
    }
  }

  /** Toggles broadcast mode for the current tab. */
  function toggleBroadcast(): void {
    const tab = activeTab.value;
    if (!tab) return;

    const existing = broadcastStates.value.get(tab.tabKey);
    const state: BroadcastState = existing ?? {
      enabled: false,
      includedPaneIds: new Set<string>(),
    };

    state.enabled = !state.enabled;

    // When enabling, include all panes by default
    if (state.enabled) {
      const layout = paneLayouts.value.get(tab.tabKey);
      if (layout) {
        state.includedPaneIds = new Set(paneTree.collectLeafIds(layout));
      }
    }

    broadcastStates.value.set(tab.tabKey, state);
  }

  /** Toggles a specific pane's inclusion in broadcast. */
  function togglePaneBroadcast(paneId: string): void {
    const tab = activeTab.value;
    if (!tab) return;

    const state = broadcastStates.value.get(tab.tabKey);
    if (!state) return;

    if (state.includedPaneIds.has(paneId)) {
      state.includedPaneIds.delete(paneId);
    } else {
      state.includedPaneIds.add(paneId);
    }
  }

  /** Focuses the next/previous pane in DFS order. */
  function focusAdjacentPane(direction: "next" | "prev"): void {
    if (!activePaneId.value) return;
    const tab = activeTab.value;
    if (!tab) return;
    const layout = paneLayouts.value.get(tab.tabKey);
    if (!layout) return;

    const targetId = paneTree.findAdjacentLeaf(layout, activePaneId.value, direction);
    if (targetId) {
      activePaneId.value = targetId;
    }
  }

  /** Focuses the pane in a spatial direction (up/down/left/right). */
  function focusPaneInDirection(direction: "up" | "down" | "left" | "right"): void {
    if (!activePaneId.value) return;
    const tab = activeTab.value;
    if (!tab) return;
    const layout = paneLayouts.value.get(tab.tabKey);
    if (!layout) return;

    const targetId = paneTree.findPaneInDirection(layout, activePaneId.value, direction);
    if (targetId) {
      activePaneId.value = targetId;
    }
  }

  // ── Cloud session entry points ──────────────────────────────

  /** Opens a kubectl exec session tab. */
  function openKubeExec(params: {
    context: string;
    namespace: string;
    pod: string;
    container?: string;
    shell?: string;
  }): string {
    const tabKey = `tab-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
    const sessionId = `kube-${tabKey}`;

    const cloudMeta: CloudMeta = {
      context: params.context,
      namespace: params.namespace,
      pod: params.pod,
      container: params.container,
    };

    const session: Session = {
      id: sessionId,
      serverId: "",
      serverName: params.pod,
      status: "connecting",
      startedAt: new Date().toISOString(),
      type: "kube-exec",
      cloudMeta,
    };
    sessions.value.set(sessionId, session);

    const tab: Tab = {
      tabKey,
      id: sessionId,
      sessionId,
      title: `${params.pod} [k8s]`,
      active: true,
    };
    tabs.value.forEach((t) => (t.active = false));
    tabs.value.push(tab);

    const initialLeaf = paneTree.createLeaf(sessionId, "", params.pod);
    paneLayouts.value.set(tabKey, initialLeaf);
    activePaneId.value = initialLeaf.id;

    return sessionId;
  }

  /** Opens an AWS SSM session tab. */
  function openSsmSession(params: {
    instanceId: string;
    instanceName: string;
    profile?: string;
    region?: string;
  }): string {
    const tabKey = `tab-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
    const sessionId = `ssm-${tabKey}`;

    const cloudMeta: CloudMeta = {
      instanceId: params.instanceId,
      instanceName: params.instanceName,
      profile: params.profile,
      region: params.region,
    };

    const session: Session = {
      id: sessionId,
      serverId: "",
      serverName: params.instanceName,
      status: "connecting",
      startedAt: new Date().toISOString(),
      type: "ssm",
      cloudMeta,
    };
    sessions.value.set(sessionId, session);

    const tab: Tab = {
      tabKey,
      id: sessionId,
      sessionId,
      title: `${params.instanceName} [ssm]`,
      active: true,
    };
    tabs.value.forEach((t) => (t.active = false));
    tabs.value.push(tab);

    const initialLeaf = paneTree.createLeaf(sessionId, "", params.instanceName);
    paneLayouts.value.set(tabKey, initialLeaf);
    activePaneId.value = initialLeaf.id;

    return sessionId;
  }

  /** Opens a kubectl logs stream tab (read-only). */
  function openKubeLogs(params: {
    context: string;
    namespace: string;
    pod: string;
    container?: string;
    tailLines?: number;
  }): string {
    const tabKey = `tab-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
    const sessionId = `kube-logs-${tabKey}`;

    const cloudMeta: CloudMeta = {
      context: params.context,
      namespace: params.namespace,
      pod: params.pod,
      container: params.container,
    };

    const session: Session = {
      id: sessionId,
      serverId: "",
      serverName: params.pod,
      status: "connected",
      startedAt: new Date().toISOString(),
      type: "kube-logs",
      cloudMeta,
    };
    sessions.value.set(sessionId, session);

    const tab: Tab = {
      tabKey,
      id: sessionId,
      sessionId,
      title: `${params.pod} [logs]`,
      active: true,
    };
    tabs.value.forEach((t) => (t.active = false));
    tabs.value.push(tab);

    const initialLeaf = paneTree.createLeaf(sessionId, "", params.pod);
    paneLayouts.value.set(tabKey, initialLeaf);
    activePaneId.value = initialLeaf.id;

    return sessionId;
  }

  /** Sets the active pane ID directly (used by PaneContainer on click). */
  function setActivePane(paneId: string): void {
    activePaneId.value = paneId;

    // Also update tab.active flags
    for (const tab of tabs.value) {
      const layout = paneLayouts.value.get(tab.tabKey);
      tab.active = !!(layout && paneTree.findLeaf(layout, paneId));
    }
  }

  return {
    sessions,
    tabs,
    activeSessionId,
    activeSession,
    activeTab,
    connect,
    openLocalTerminal,
    openKubeExec,
    openSsmSession,
    openKubeLogs,
    openShell,
    disconnect,
    isDeliberateDisconnect,
    reconnectSession,
    updateStatus,
    setActive,
    closeTab,
    closeTabByKey,
    // Pane management
    paneLayouts,
    activePaneId,
    broadcastStates,
    currentPaneLayout,
    currentBroadcast,
    paneCount,
    updatePaneSessionId,
    updatePaneSessionIdBySession,
    splitActivePane,
    closePane,
    toggleBroadcast,
    togglePaneBroadcast,
    focusAdjacentPane,
    focusPaneInDirection,
    setActivePane,
  };
});
