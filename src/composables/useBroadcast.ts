import { computed } from "vue";
import { useSessionStore } from "@/stores/sessionStore";
import { tauriInvoke } from "@/utils/tauri";
import * as paneTree from "@/utils/paneTree";

export function useBroadcast() {
  const sessionStore = useSessionStore();

  const isActive = computed(() => sessionStore.currentBroadcast?.enabled ?? false);
  const broadcastPaneIds = computed(() => sessionStore.currentBroadcast?.includedPaneIds ?? new Set<string>());

  /** Resolves session IDs for all broadcast-included panes. */
  function getBroadcastSessionIds(): string[] {
    const tab = sessionStore.activeTab;
    if (!tab) return [];

    const layout = sessionStore.paneLayouts.get(tab.tabKey);
    if (!layout) return [];

    const allLeafIds = paneTree.collectLeafIds(layout);
    const includedIds = broadcastPaneIds.value;

    return allLeafIds
      .filter((id) => includedIds.has(id))
      .map((id) => {
        const leaf = paneTree.findLeaf(layout, id);
        return leaf?.sessionId ?? null;
      })
      .filter((id): id is string => id !== null && !id.startsWith("connecting-"));
  }

  /** Resolves the correct write command for a session. */
  function getWriteCmd(sessionId: string): string {
    const session = sessionStore.sessions.get(sessionId);
    return session?.type === "local" ? "local_pty_write" : "ssh_write";
  }

  /** Sends input data to all broadcast targets.
   *  Called from useTerminal.ts when broadcast is active. */
  async function broadcastInput(data: string): Promise<void> {
    if (!isActive.value) return;

    const sessionIds = getBroadcastSessionIds();
    const activeSid = sessionStore.activeSessionId;

    // Send to all broadcast targets EXCEPT the active one (already handled by normal input)
    const targets = sessionIds.filter((sid) => sid !== activeSid);
    if (targets.length === 0) return;

    // Encode once, reuse for all targets (match useTerminal.ts encoding)
    const bytes = Array.from(new TextEncoder().encode(data));

    await Promise.allSettled(
      targets.map((sid) => tauriInvoke(getWriteCmd(sid), { sessionId: sid, data: bytes })),
    );
  }

  return {
    isActive,
    broadcastPaneIds,
    broadcastInput,
    getBroadcastSessionIds,
  };
}
