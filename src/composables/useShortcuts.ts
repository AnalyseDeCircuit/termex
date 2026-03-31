import { onMounted, onUnmounted } from "vue";
import { useSessionStore } from "@/stores/sessionStore";

interface ShortcutHandlers {
  toggleSidebar: () => void;
  openNewConnection: () => void;
  openSettings: () => void;
}

/**
 * Registers global keyboard shortcuts for the application.
 */
export function useShortcuts(handlers: ShortcutHandlers) {
  const sessionStore = useSessionStore();

  function onKeydown(e: KeyboardEvent) {
    const mod = e.ctrlKey || e.metaKey;

    // Ctrl+\ — toggle sidebar
    if (mod && e.key === "\\") {
      e.preventDefault();
      e.stopImmediatePropagation();
      handlers.toggleSidebar();
      return;
    }

    // Ctrl+N — new connection
    if (mod && e.key === "n") {
      e.preventDefault();
      e.stopImmediatePropagation();
      handlers.openNewConnection();
      return;
    }

    // Ctrl+, — open settings
    if (mod && e.key === ",") {
      e.preventDefault();
      e.stopImmediatePropagation();
      handlers.openSettings();
      return;
    }

    // Ctrl+W — close current tab
    if (mod && e.key === "w") {
      e.preventDefault();
      e.stopImmediatePropagation();
      if (sessionStore.activeSessionId) {
        sessionStore.disconnect(sessionStore.activeSessionId);
      }
      return;
    }

    // Ctrl+Tab — next tab
    if (mod && e.key === "Tab" && !e.shiftKey) {
      e.preventDefault();
      e.stopImmediatePropagation();
      cycleTab(1);
      return;
    }

    // Ctrl+Shift+Tab — previous tab
    if (mod && e.key === "Tab" && e.shiftKey) {
      e.preventDefault();
      e.stopImmediatePropagation();
      cycleTab(-1);
      return;
    }

    // Ctrl+1~9 — go to tab N
    if (mod && e.key >= "1" && e.key <= "9") {
      e.preventDefault();
      e.stopImmediatePropagation();
      const idx = parseInt(e.key) - 1;
      const tab = sessionStore.tabs[idx];
      if (tab) {
        sessionStore.setActive(tab.sessionId);
      }
      return;
    }
  }

  function cycleTab(direction: number) {
    const tabs = sessionStore.tabs;
    if (tabs.length <= 1) return;
    const currentIdx = tabs.findIndex(
      (t) => t.sessionId === sessionStore.activeSessionId,
    );
    const nextIdx = (currentIdx + direction + tabs.length) % tabs.length;
    sessionStore.setActive(tabs[nextIdx].sessionId);
  }

  // Use capture phase so shortcuts are intercepted before xterm.js receives the event
  onMounted(() => window.addEventListener("keydown", onKeydown, true));
  onUnmounted(() => window.removeEventListener("keydown", onKeydown, true));
}
