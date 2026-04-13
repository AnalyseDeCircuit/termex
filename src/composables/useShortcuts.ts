import { onMounted, onUnmounted } from "vue";
import { useSessionStore } from "@/stores/sessionStore";
import { useSettingsStore } from "@/stores/settingsStore";
import { matchesEvent } from "@/types/keybindings";
import type { KeybindingAction } from "@/types/keybindings";

interface ShortcutHandlers {
  toggleSidebar: () => void;
  toggleAi: () => void;
  closeTab: () => void;
  openNewConnection: () => void;
  openSettings: () => void;
  openSearch?: () => void;
  openCrossTabSearch?: () => void;
  openSnippetPalette?: () => void;
  toggleMonitor?: () => void;
}

/**
 * Registers global keyboard shortcuts for the application.
 * Reads keybinding config from settingsStore for data-driven matching.
 */
export function useShortcuts(handlers: ShortcutHandlers) {
  const sessionStore = useSessionStore();
  const settingsStore = useSettingsStore();

  /** Action handlers mapped by action ID. */
  const actionHandlers: Partial<Record<KeybindingAction, () => void>> = {
    newConnection: () => handlers.openNewConnection(),
    openSettings: () => handlers.openSettings(),
    toggleSidebar: () => handlers.toggleSidebar(),
    toggleAi: () => handlers.toggleAi(),
    nextTab: () => cycleTab(1),
    prevTab: () => cycleTab(-1),
    search: () => handlers.openSearch?.(),
    searchAllTabs: () => handlers.openCrossTabSearch?.(),
    toggleMonitor: () => handlers.toggleMonitor?.(),
    // Pane actions
    splitVertical: () => sessionStore.splitActivePane("vertical"),
    splitHorizontal: () => sessionStore.splitActivePane("horizontal"),
    closePaneOrTab: () => {
      if (sessionStore.paneCount > 1 && sessionStore.activePaneId) {
        sessionStore.closePane(sessionStore.activePaneId);
      } else {
        handlers.closeTab();
      }
    },
    focusPaneNext: () => sessionStore.focusAdjacentPane("next"),
    focusPanePrev: () => sessionStore.focusAdjacentPane("prev"),
    focusPaneUp: () => sessionStore.focusPaneInDirection("up"),
    focusPaneDown: () => sessionStore.focusPaneInDirection("down"),
    focusPaneLeft: () => sessionStore.focusPaneInDirection("left"),
    focusPaneRight: () => sessionStore.focusPaneInDirection("right"),
    toggleBroadcast: () => sessionStore.toggleBroadcast(),
  };

  function onKeydown(e: KeyboardEvent) {
    const bindings = settingsStore.keybindings;

    // Snippet Palette: Cmd/Ctrl+Shift+S
    if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === "s") {
      e.preventDefault();
      e.stopImmediatePropagation();
      handlers.openSnippetPalette?.();
      return;
    }

    // Check non-goToTab actions first
    for (const [action, handler] of Object.entries(actionHandlers)) {
      const binding = bindings[action as KeybindingAction];
      if (binding && binding.key && matchesEvent(e, binding)) {
        e.preventDefault();
        e.stopImmediatePropagation();
        handler();
        return;
      }
    }

    // goToTab1~9
    for (let i = 1; i <= 9; i++) {
      const action = `goToTab${i}` as KeybindingAction;
      if (matchesEvent(e, bindings[action])) {
        e.preventDefault();
        e.stopImmediatePropagation();
        const tab = sessionStore.tabs[i - 1];
        if (tab) sessionStore.setActive(tab.sessionId);
        return;
      }
    }
  }

  function cycleTab(direction: number) {
    const tabs = sessionStore.tabs;
    if (tabs.length <= 1) return;
    const currentTab = sessionStore.activeTab;
    const currentIdx = currentTab ? tabs.indexOf(currentTab) : -1;
    if (currentIdx === -1) return;
    const nextIdx = (currentIdx + direction + tabs.length) % tabs.length;
    sessionStore.setActive(tabs[nextIdx].sessionId);
  }

  // Use capture phase so shortcuts are intercepted before xterm.js receives the event
  onMounted(() => window.addEventListener("keydown", onKeydown, true));
  onUnmounted(() => window.removeEventListener("keydown", onKeydown, true));
}
