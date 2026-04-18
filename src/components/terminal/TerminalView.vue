<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, toRef, nextTick } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage } from "element-plus";
import { useTerminal } from "@/composables/useTerminal";
import { useTerminalSearch } from "@/composables/useTerminalSearch";
import { useKeywordHighlight } from "@/composables/useKeywordHighlight";
import { useCommandTracker } from "@/composables/useCommandTracker";
import { useTerminalAutocomplete } from "@/composables/useTerminalAutocomplete";
import { useReconnect } from "@/composables/useReconnect";
import { useAiContext, extractRecentLines } from "@/composables/useAiContext";
import { useErrorDetection } from "@/composables/useErrorDetection";
import { tauriInvoke } from "@/utils/tauri";
import { useTmux } from "@/composables/useTmux";
import { useGitSync } from "@/composables/useGitSync";
import { useSessionStore } from "@/stores/sessionStore";
import { useSettingsStore } from "@/stores/settingsStore";
import { useServerStore } from "@/stores/serverStore";
import { usePortForwardStore } from "@/stores/portForwardStore";
import TerminalSearchBar from "./TerminalSearchBar.vue";
import AutocompletePopup from "./AutocompletePopup.vue";
import SelectionToolbar from "./SelectionToolbar.vue";

const props = defineProps<{
  sessionId: string;
  paneId?: string;
  topPadding?: number;
}>();

const { t } = useI18n();
const sessionStore = useSessionStore();
const settingsStore = useSettingsStore();
const serverStore = useServerStore();
const portForwardStore = usePortForwardStore();
const containerRef = ref<HTMLElement>();
const sessionIdRef = toRef(props, "sessionId");
const reconnectCtrl = useReconnect();

const isPlaceholder = computed(() => props.sessionId.startsWith("connecting-"));
const session = computed(() => sessionStore.sessions.get(props.sessionId));
const isActive = computed(() => sessionStore.activeSessionId === props.sessionId);

// tmux + git sync integration
const tmux = useTmux();
const gitSync = useGitSync();

// AI autocomplete integration
const commandTracker = useCommandTracker(
  () => getTerminal(),
  sessionIdRef,
);
const autocomplete = useTerminalAutocomplete(
  () => getTerminal(),
  sessionIdRef,
  commandTracker.state,
  commandTracker.recentCommands,
);

/** Post-shell setup: tmux, git sync, port forwards. Reused after reconnect. */
async function onShellReady(sid: string) {
  const sess = sessionStore.sessions.get(sid);
  if (!sess) return;
  const server = serverStore.servers.find((s) => s.id === sess.serverId);
  if (!server) return;

  // tmux init
  if (server.tmuxMode !== "disabled") {
    await tmux.initTmux(sid, server.id, server.tmuxMode, server.startupCmd);
  }

  // Git Auto Sync
  if (server.gitSyncEnabled) {
    await gitSync.setupSync(sid, server.id, server.gitSyncMode, server.gitSyncLocalPath);
  }

  // Start all port forwards for this server
  await portForwardStore.loadForwards(server.id);
  for (const fw of portForwardStore.getForwards(server.id)) {
    if (!portForwardStore.isActive(fw.id)) {
      await portForwardStore.startForward(sid, fw).catch(() => {});
    }
  }
}

const { mount, fit, setTheme, setFont, getSearchAddon, getTerminal, rebindSession, getDimensions, dispose, mouseReporting } =
  useTerminal(sessionIdRef, {
    getAutocomplete: () => autocomplete,
    onShellReady,
    onDisconnect: (sid) => {
      if (sessionStore.isDeliberateDisconnect(sid)) return;
      startAutoReconnect(sid);
    },
  });

/** Attempts automatic reconnection with exponential backoff. */
async function startAutoReconnect(disconnectedSid: string) {
  const session = sessionStore.sessions.get(disconnectedSid);
  if (!session || session.type !== "ssh") return;

  const term = getTerminal();
  if (!term) return;

  const newSid = await reconnectCtrl.reconnect(session.serverId, disconnectedSid, term);
  if (!newSid) return;

  const { cols, rows } = getDimensions();
  await sessionStore.reconnectSession(disconnectedSid, newSid, cols, rows);
  // Tab sessionId change triggers watcher → rebindSession
  term.write(`\r\n\x1b[32m[${t("terminal.reconnected")}]\x1b[0m\r\n`);
  await onShellReady(newSid).catch(() => {});
}

/** Manual reconnect triggered by the user (reconnect button or context menu). */
async function manualReconnect() {
  const sid = props.sessionId;
  const session = sessionStore.sessions.get(sid);
  if (!session || session.type !== "ssh") return;

  const term = getTerminal();
  if (!term) return;

  // Cancel any ongoing auto-reconnect
  reconnectCtrl.cancel();

  sessionStore.updateStatus(sid, "reconnecting");
  term.write(`\r\n\x1b[33m[${t("terminal.reconnecting")}]\x1b[0m\r\n`);

  // Clean up old backend session
  try {
    await tauriInvoke("ssh_disconnect", { sessionId: sid });
  } catch { /* already gone */ }

  try {
    const newSid = await tauriInvoke<string>("ssh_connect", { serverId: session.serverId });
    const { cols, rows } = getDimensions();
    await sessionStore.reconnectSession(sid, newSid, cols, rows);
    term.write(`\r\n\x1b[32m[${t("terminal.reconnected")}]\x1b[0m\r\n`);
    await onShellReady(newSid).catch(() => {});
  } catch {
    term.write(`\r\n\x1b[31m[${t("terminal.reconnectFailed")}]\x1b[0m\r\n`);
    sessionStore.updateStatus(sid, "disconnected");
  }
}

// Search integration
const search = useTerminalSearch(getSearchAddon);
const searchBarRef = ref<InstanceType<typeof TerminalSearchBar>>();

// Selection toolbar state
const selectionToolbar = ref({ visible: false, x: 0, y: 0, text: "" });

function initSelectionToolbar() {
  const term = getTerminal();
  if (!term) return;
  term.onSelectionChange(() => {
    const sel = term.getSelection();
    if (sel && sel.trim().length > 0 && containerRef.value) {
      const rect = containerRef.value.getBoundingClientRect();
      // Position toolbar above the selection (approximate via cursor row)
      const cellHeight = term.options.fontSize ?? 14;
      const bufferY = term.buffer.active.cursorY;
      const y = Math.max(0, bufferY * cellHeight - 4);
      const x = rect.width / 2 - 44; // center roughly
      selectionToolbar.value = { visible: true, x, y, text: sel };
    } else {
      selectionToolbar.value = { ...selectionToolbar.value, visible: false };
    }
  });
}

function onSelectionCopy() {
  navigator.clipboard.writeText(selectionToolbar.value.text);
  selectionToolbar.value.visible = false;
}

const emit = defineEmits<{
  (e: "save-snippet", text: string): void;
  (e: "explain-command", text: string): void;
}>();

function onSelectionSaveSnippet() {
  emit("save-snippet", selectionToolbar.value.text);
  selectionToolbar.value.visible = false;
}

function onSelectionExplain() {
  emit("explain-command", selectionToolbar.value.text);
  selectionToolbar.value.visible = false;
}

// Mouse reporting hint: one-time notification when first detected
const MOUSE_HINT_KEY = "termex:mouse-reporting-hint-shown";
watch(mouseReporting, (active) => {
  if (active && !localStorage.getItem(MOUSE_HINT_KEY)) {
    localStorage.setItem(MOUSE_HINT_KEY, "1");
    const isMac = navigator.platform.startsWith("Mac");
    ElMessage.info({
      message: t("terminal.mouseReportingHint", { key: isMac ? "Shift" : "Shift" }),
      duration: 6000,
      showClose: true,
    });
  }
});

// Keyword highlight integration
const keywordRulesRef = toRef(settingsStore, "keywordRules");
const highlight = useKeywordHighlight(getTerminal, keywordRulesRef);

// AI context capture + error detection
const aiContext = useAiContext(getTerminal, sessionIdRef);
const errorDetection = useErrorDetection(getTerminal, sessionIdRef);

/** Opens the search bar (called from parent via expose). */
function openSearch() {
  search.open();
  nextTick(() => searchBarRef.value?.focus());
}

/** Closes the search bar and returns focus to terminal. */
function closeSearch() {
  search.close();
  const term = getTerminal();
  term?.focus();
}

// ── Terminal right-click context menu (for reconnect) ──
const terminalCtxVisible = ref(false);
const terminalCtxX = ref(0);
const terminalCtxY = ref(0);

/** Right-click context menu mode: "reconnect" when disconnected, "pane" when connected. */
const terminalCtxMode = ref<"reconnect" | "pane">("reconnect");

function onTerminalContextMenu(e: MouseEvent) {
  const status = session.value?.status;

  if (status === "disconnected" || status === "reconnecting") {
    terminalCtxMode.value = "reconnect";
  } else if (status === "connected" || status === "authenticated") {
    terminalCtxMode.value = "pane";
  } else if ((status === "connecting" || status === "error") && sessionStore.paneCount > 1) {
    // Connecting/error panes: only show close option when multi-pane
    terminalCtxMode.value = "pane";
  } else {
    return;
  }

  e.preventDefault();
  terminalCtxX.value = e.clientX;
  terminalCtxY.value = e.clientY;
  terminalCtxVisible.value = true;

  // Close on next click anywhere
  const close = () => {
    terminalCtxVisible.value = false;
    document.removeEventListener("click", close);
    document.removeEventListener("contextmenu", close);
  };
  setTimeout(() => {
    document.addEventListener("click", close);
    document.addEventListener("contextmenu", close);
  }, 0);
}

function onCtxSplitVertical() {
  terminalCtxVisible.value = false;
  if (props.paneId) sessionStore.setActivePane(props.paneId);
  sessionStore.splitActivePane("vertical");
}

function onCtxSplitHorizontal() {
  terminalCtxVisible.value = false;
  if (props.paneId) sessionStore.setActivePane(props.paneId);
  sessionStore.splitActivePane("horizontal");
}

function onCtxClosePane() {
  terminalCtxVisible.value = false;
  if (props.paneId) sessionStore.closePane(props.paneId);
}

function onTerminalCtxReconnect() {
  terminalCtxVisible.value = false;
  manualReconnect();
}

onMounted(async () => {
  if (containerRef.value && !isPlaceholder.value) {
    await mount(containerRef.value);
    highlight.init();
    commandTracker.init();
    errorDetection.init();
    initSelectionToolbar();
  }
  // Register global AI context capture functions
  window.__termexCaptureContext = (sid: string) => {
    if (props.sessionId !== sid) return null;
    return aiContext.captureContext();
  };
  window.__termexCaptureBuffer = (sid: string, lines: number) => {
    if (props.sessionId !== sid) return "";
    const term = getTerminal();
    if (!term) return "";
    return extractRecentLines(term, lines);
  };
});

// When placeholder gets replaced with real session, mount terminal.
// When sessionId changes between two real IDs (reconnect), rebind listeners only.
watch(
  () => props.sessionId,
  async (newId, oldId) => {
    if (!newId.startsWith("connecting-") && containerRef.value) {
      const wasPlaceholder = oldId?.startsWith("connecting-");
      if (wasPlaceholder) {
        // First mount: placeholder → real session
        await nextTick();
        await mount(containerRef.value);
        highlight.init();
        commandTracker.init();
        errorDetection.init();
        initSelectionToolbar();
      } else if (oldId) {
        // Reconnect: old real session → new real session
        // Terminal instance is preserved; just rebind event listeners
        await rebindSession(oldId, newId);
      }
    }
  },
);

// Focus terminal when this tab becomes active
watch(isActive, async (active) => {
  if (active && !isPlaceholder.value) {
    await nextTick();
    fit();
  }
});

// Update terminal theme when appearance setting changes
watch(() => settingsStore.theme, () => {
  if (!isPlaceholder.value) {
    setTheme();
  }
});

// Update terminal font when font settings change
watch(
  () => [settingsStore.fontFamily, settingsStore.fontSize],
  ([family, size]) => {
    if (!isPlaceholder.value) {
      setFont(family as string, size as number);
    }
  },
);

onUnmounted(() => {
  reconnectCtrl.cancel();
  errorDetection.dispose();
});

defineExpose({
  fit, dispose, openSearch, search, getTerminal,
  tmuxStatus: tmux.status, cleanupTmux: tmux.cleanupTmux,
  commandTracker, autocomplete,
  manualReconnect, reconnectActive: reconnectCtrl.active,
});
</script>

<template>
  <div class="w-full h-full relative overflow-hidden flex flex-col" style="background: var(--tm-terminal-bg)">
    <!-- Top spacer for floating tab bar (not padding — so FitAddon sees correct height) -->
    <div v-if="topPadding" class="shrink-0" :style="{ height: `${topPadding}px` }" />
    <!-- Terminal container (padding on .xterm so FitAddon accounts for it) -->
    <div
      ref="containerRef"
      class="terminal-container w-full flex-1 min-h-0 overflow-hidden"
      @contextmenu="onTerminalContextMenu"
    />

    <!-- Search bar overlay -->
    <TerminalSearchBar
      ref="searchBarRef"
      :visible="search.searchVisible.value"
      :search-term="search.searchTerm.value"
      :search-options="search.searchOptions.value"
      :match-index="search.matchIndex.value"
      :match-count="search.matchCount.value"
      @update:search-term="search.searchTerm.value = $event"
      @update:search-options="search.searchOptions.value = $event"
      @find-next="search.findNext()"
      @find-previous="search.findPrevious()"
      @close="closeSearch"
    />

    <!-- Connecting / Error overlay -->
    <div
      v-if="isPlaceholder"
      class="absolute inset-0 flex items-center justify-center"
      @contextmenu="onTerminalContextMenu"
    >
      <div class="text-center">
        <template v-if="session?.status === 'connecting'">
          <div class="text-yellow-500 text-sm mb-2 animate-pulse">Connecting...</div>
          <div class="text-xs" style="color: var(--tm-text-muted)">{{ session.serverName }}</div>
        </template>
        <template v-else-if="session?.status === 'error'">
          <div class="text-red-400 text-sm mb-2">Connection Failed</div>
          <div class="text-xs" style="color: var(--tm-text-muted)">{{ session.serverName }}</div>
        </template>
        <!-- Close pane button (only when multi-pane) -->
        <button
          v-if="sessionStore.paneCount > 1"
          class="mt-3 px-3 py-1 rounded text-xs transition-colors cursor-pointer hover:brightness-125"
          style="background: var(--tm-bg-elevated); color: var(--tm-text-muted); border: 1px solid var(--tm-border)"
          @click="onCtxClosePane"
        >
          {{ t("terminal.closePane") }}
        </button>
      </div>
    </div>

    <!-- Disconnected reconnect button -->
    <div
      v-if="session?.status === 'disconnected' && !reconnectCtrl.active.value"
      class="absolute bottom-4 left-1/2 -translate-x-1/2 z-20"
    >
      <button
        class="px-4 py-1.5 rounded text-xs font-medium transition-colors cursor-pointer hover:brightness-125"
        style="background: var(--tm-bg-elevated); color: var(--tm-text-primary); border: 1px solid var(--tm-border)"
        @click.stop="manualReconnect"
      >
        &#x21BB; {{ t("terminal.reconnect") }}
      </button>
    </div>

    <!-- Terminal right-click context menu -->
    <Teleport to="body">
      <div
        v-if="terminalCtxVisible"
        class="fixed z-50"
        :style="{ left: terminalCtxX + 'px', top: terminalCtxY + 'px' }"
      >
        <div
          class="py-1 rounded shadow-lg text-xs min-w-[160px]"
          style="background: var(--tm-bg-elevated); border: 1px solid var(--tm-border)"
        >
          <!-- Reconnect mode (disconnected) -->
          <template v-if="terminalCtxMode === 'reconnect'">
            <button
              class="pane-ctx-item w-full text-left px-3 py-1.5 cursor-pointer"
              style="color: var(--tm-text-primary)"
              @click="onTerminalCtxReconnect"
            >
              &#x21BB; {{ t("terminal.reconnect") }}
            </button>
          </template>

          <!-- Pane mode (connected) -->
          <template v-else>
            <button
              class="pane-ctx-item w-full text-left px-3 py-1.5 cursor-pointer"
              style="color: var(--tm-text-primary)"
              @click="onCtxSplitVertical"
            >
              {{ t("terminal.splitVertical") }}
            </button>
            <button
              class="pane-ctx-item w-full text-left px-3 py-1.5 cursor-pointer"
              style="color: var(--tm-text-primary)"
              @click="onCtxSplitHorizontal"
            >
              {{ t("terminal.splitHorizontal") }}
            </button>
            <template v-if="sessionStore.paneCount > 1">
              <div class="h-px mx-2 my-1" style="background: var(--tm-border)" />
              <button
                class="pane-ctx-item w-full text-left px-3 py-1.5 cursor-pointer"
                style="color: var(--tm-text-primary)"
                @click="onCtxClosePane"
              >
                {{ t("terminal.closePane") }}
              </button>
            </template>
          </template>
        </div>
      </div>
    </Teleport>

    <!-- Mouse reporting mode indicator -->
    <Transition name="mouse-hint-fade">
      <div
        v-if="mouseReporting"
        class="absolute bottom-1.5 right-2 z-10 flex items-center gap-1 px-2 py-0.5 rounded text-[10px] select-none pointer-events-none"
        style="background: rgba(0, 0, 0, 0.55); color: var(--tm-text-muted); backdrop-filter: blur(4px)"
      >
        <svg class="w-3 h-3 shrink-0 opacity-70" viewBox="0 0 24 24" fill="currentColor">
          <path d="M4 0l16 12.279-6.951 1.17 4.325 8.817-3.596 1.734-4.35-8.879-5.428 4.702z" />
        </svg>
        {{ t("terminal.mouseReportingActive", { key: "Shift" }) }}
      </div>
    </Transition>

    <!-- Selection floating toolbar -->
    <SelectionToolbar
      :visible="selectionToolbar.visible"
      :x="selectionToolbar.x"
      :y="selectionToolbar.y"
      @copy="onSelectionCopy"
      @save-snippet="onSelectionSaveSnippet"
      @explain="onSelectionExplain"
    />

    <!-- AI Autocomplete popup -->
    <AutocompletePopup
      :suggestions="autocomplete.suggestions.value"
      :selected-index="autocomplete.selectedIndex.value"
      :visible="autocomplete.popupVisible.value"
      :pos-x="autocomplete.popupPos.value.x"
      :pos-y="autocomplete.popupPos.value.y"
      @select="autocomplete.selectSuggestion($event)"
      @dismiss="autocomplete.dismiss()"
    />
  </div>
</template>

<style scoped>
.terminal-container :deep(.xterm) {
  padding: 6px;
  /* Improve font rendering on Windows (ClearType) and macOS (subpixel) */
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
}

.mouse-hint-fade-enter-active,
.mouse-hint-fade-leave-active {
  transition: opacity 0.25s ease;
}
.mouse-hint-fade-enter-from,
.mouse-hint-fade-leave-to {
  opacity: 0;
}
</style>
