import { ref, watch, type Ref } from "vue";
import type { Terminal } from "@xterm/xterm";
import type { CommandLineState } from "@/types/commandTracker";
import { useTerminalGhostText, getCellDimensions } from "./useTerminalGhostText";
import { useSettingsStore } from "@/stores/settingsStore";
import { useSessionStore } from "@/stores/sessionStore";
import { useAiStore } from "@/stores/aiStore";
import { tauriInvoke } from "@/utils/tauri";

/**
 * Central autocomplete composable that orchestrates:
 * - Watching command state changes (from useCommandTracker)
 * - Debounced AI requests with cancellation
 * - Ghost text rendering
 * - Popup state management
 * - LRU cache for recent completions
 */
export function useTerminalAutocomplete(
  getTerminal: () => Terminal | null,
  sessionId: Ref<string>,
  commandState: Ref<CommandLineState>,
) {
  const suggestion = ref<string | null>(null);
  const suggestions = ref<string[]>([]);
  const selectedIndex = ref(0);
  const popupVisible = ref(false);
  const loading = ref(false);
  const popupPos = ref({ x: 0, y: 0 });

  const settingsStore = useSettingsStore();
  const sessionStore = useSessionStore();
  const aiStore = useAiStore();
  const ghostText = useTerminalGhostText(getTerminal);

  // LRU cache (key: partialCommand, capacity: 100)
  const cache = new Map<string, string[]>();
  const CACHE_MAX = 100;

  let debounceTimer: ReturnType<typeof setTimeout> | null = null;
  let requestId = 0;

  // Watch command changes
  watch(
    () => commandState.value.command,
    (cmd) => {
      if (!settingsStore.autocompleteEnabled) return;
      if (!commandState.value.atPrompt) return;

      // Only trigger for the active tab
      const activeTab = sessionStore.activeTab;
      if (!activeTab || activeTab.sessionId !== sessionId.value) {
        dismiss();
        return;
      }

      // Clear current suggestions on any input change
      dismiss();

      // Don't trigger for short input
      if (cmd.length < settingsStore.autocompleteMinChars) return;

      // Debounce
      if (debounceTimer) clearTimeout(debounceTimer);
      debounceTimer = setTimeout(
        () => fetchSuggestions(cmd),
        settingsStore.autocompleteDebounceMs,
      );
    },
  );

  async function fetchSuggestions(partialCommand: string) {
    // Global semaphore: only 1 request at a time
    if (aiStore.autocompleteInFlight) return;

    const currentId = ++requestId;
    const cacheKey = partialCommand;

    // Check cache
    if (cache.has(cacheKey)) {
      applySuggestions(cache.get(cacheKey)!, partialCommand, currentId);
      return;
    }

    aiStore.autocompleteInFlight = true;
    loading.value = true;

    try {
      const result = await tauriInvoke<string[]>("ai_autocomplete", {
        context: {
          partialCommand,
          os: undefined,
          shell: undefined,
          cwd: undefined,
          recentCommands: [],
        },
      });

      if (requestId !== currentId) return; // Stale response

      // Cache result (LRU eviction)
      if (cache.size >= CACHE_MAX) {
        const firstKey = cache.keys().next().value;
        if (firstKey !== undefined) cache.delete(firstKey);
      }
      cache.set(cacheKey, result);

      applySuggestions(result, partialCommand, currentId);
    } catch {
      // Silent failure — autocomplete is optional enhancement
    } finally {
      loading.value = false;
      aiStore.autocompleteInFlight = false;
    }
  }

  function applySuggestions(
    items: string[],
    partialCommand: string,
    id: number,
  ) {
    if (requestId !== id) return;
    suggestions.value = items;
    selectedIndex.value = 0;

    if (items.length > 0) {
      // Compute completion suffix
      const full = items[0];
      const suffix = full.startsWith(partialCommand)
        ? full.slice(partialCommand.length)
        : full;
      suggestion.value = suffix;
      ghostText.show(suffix);
      updatePopupPosition();
    }
  }

  /** Tab: accept current ghost text suggestion. */
  function accept() {
    if (!suggestion.value) return;

    const bytes = new TextEncoder().encode(suggestion.value);
    const writeCmd = sessionId.value.startsWith("local-")
      ? "local_pty_write"
      : "ssh_write";
    tauriInvoke(writeCmd, {
      sessionId: sessionId.value,
      data: Array.from(bytes),
    }).catch(() => {});

    dismiss();
  }

  /** Escape or new input: clear all suggestions. */
  function dismiss() {
    suggestion.value = null;
    suggestions.value = [];
    popupVisible.value = false;
    ghostText.clear();
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }
  }

  /** Ctrl+Space: show multi-select popup. */
  function showPopup() {
    if (suggestions.value.length > 0) {
      updatePopupPosition();
      popupVisible.value = true;
    }
  }

  /** Alt+]: next suggestion. */
  function nextSuggestion() {
    if (suggestions.value.length === 0) return;
    selectedIndex.value =
      (selectedIndex.value + 1) % suggestions.value.length;
    updateGhostFromSelection();
  }

  /** Alt+[: previous suggestion. */
  function prevSuggestion() {
    if (suggestions.value.length === 0) return;
    selectedIndex.value =
      (selectedIndex.value - 1 + suggestions.value.length) %
      suggestions.value.length;
    updateGhostFromSelection();
  }

  /** Select a specific suggestion from the popup. */
  function selectSuggestion(index: number) {
    if (index < 0 || index >= suggestions.value.length) return;
    selectedIndex.value = index;
    updateGhostFromSelection();
    accept();
  }

  function updateGhostFromSelection() {
    const full = suggestions.value[selectedIndex.value];
    if (!full) return;
    const cmd = commandState.value.command;
    const suffix = full.startsWith(cmd) ? full.slice(cmd.length) : full;
    suggestion.value = suffix;
    ghostText.show(suffix);
  }

  function updatePopupPosition() {
    const terminal = getTerminal();
    if (!terminal) return;
    const container = (terminal as any).element as HTMLElement | undefined;
    if (!container) return;

    const dims = getCellDimensions(terminal);
    const cursorX = terminal.buffer.active.cursorX;
    const cursorY = terminal.buffer.active.cursorY;
    const rect = container.getBoundingClientRect();

    popupPos.value = {
      x: rect.left + cursorX * dims.width,
      y: rect.top + (cursorY + 1) * dims.height,
    };
  }

  function dispose() {
    dismiss();
    ghostText.dispose();
  }

  return {
    suggestion,
    suggestions,
    selectedIndex,
    popupVisible,
    popupPos,
    loading,
    accept,
    dismiss,
    showPopup,
    nextSuggestion,
    prevSuggestion,
    selectSuggestion,
    dispose,
  };
}
