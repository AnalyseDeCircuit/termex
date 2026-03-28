import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { tauriInvoke } from "@/utils/tauri";
import type { Session, SessionStatus, Tab } from "@/types/session";

export const useSessionStore = defineStore("session", () => {
  // ── State ──────────────────────────────────────────────────

  const sessions = ref<Map<string, Session>>(new Map());
  const tabs = ref<Tab[]>([]);
  const activeSessionId = ref<string | null>(null);

  // ── Getters ────────────────────────────────────────────────

  const activeSession = computed(() => {
    if (!activeSessionId.value) return null;
    return sessions.value.get(activeSessionId.value) ?? null;
  });

  const activeTab = computed(() =>
    tabs.value.find((t) => t.sessionId === activeSessionId.value) ?? null,
  );

  // ── Actions ────────────────────────────────────────────────

  /** Opens an SSH connection and creates a tab immediately. */
  async function connect(
    serverId: string,
    serverName: string,
    cols: number,
    rows: number,
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
    activeSessionId.value = placeholderId;

    // 2. Attempt SSH connection in the background
    try {
      const realId = await tauriInvoke<string>("ssh_connect", {
        serverId,
        cols,
        rows,
      });

      // 3. Success — replace placeholder with real session
      sessions.value.delete(placeholderId);
      tab.id = realId;
      tab.sessionId = realId;

      const realSession: Session = {
        id: realId,
        serverId,
        serverName,
        status: "connected",
        startedAt: session.startedAt,
      };
      sessions.value.set(realId, realSession);

      if (activeSessionId.value === placeholderId) {
        activeSessionId.value = realId;
      }
    } catch (err) {
      // 4. Failed — update placeholder session to error
      const s = sessions.value.get(placeholderId);
      if (s) {
        s.status = "error";
      }
      throw err;
    }
  }

  /** Disconnects an SSH session and removes the tab. */
  async function disconnect(sessionId: string): Promise<void> {
    // For placeholder sessions that never connected, just remove the tab
    if (sessionId.startsWith("connecting-")) {
      closeTab(sessionId);
      return;
    }
    try {
      await tauriInvoke("ssh_disconnect", { sessionId });
    } catch {
      // Ignore disconnect errors
    }
    closeTab(sessionId);
  }

  /** Updates the status of a session. */
  function updateStatus(sessionId: string, status: SessionStatus) {
    const session = sessions.value.get(sessionId);
    if (session) {
      session.status = status;
    }
  }

  /** Sets the active tab/session. */
  function setActive(sessionId: string) {
    tabs.value.forEach((t) => (t.active = t.sessionId === sessionId));
    activeSessionId.value = sessionId;
  }

  /** Closes a tab and cleans up the session. */
  function closeTab(sessionId: string) {
    sessions.value.delete(sessionId);
    const idx = tabs.value.findIndex((t) => t.sessionId === sessionId);
    if (idx !== -1) {
      tabs.value.splice(idx, 1);
    }

    // Activate the last remaining tab, or clear
    if (activeSessionId.value === sessionId) {
      const lastTab = tabs.value[tabs.value.length - 1];
      activeSessionId.value = lastTab?.sessionId ?? null;
      if (lastTab) lastTab.active = true;
    }
  }

  return {
    sessions,
    tabs,
    activeSessionId,
    activeSession,
    activeTab,
    connect,
    disconnect,
    updateStatus,
    setActive,
    closeTab,
  };
});
