<script setup lang="ts">
import { ref, computed, nextTick, onMounted, onUnmounted } from "vue";
import { useI18n } from "vue-i18n";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { Close, Setting } from "@element-plus/icons-vue";
import { useSessionStore } from "@/stores/sessionStore";
import { useAiStore } from "@/stores/aiStore";
import { tauriInvoke, tauriListen } from "@/utils/tauri";
import ContextMenu from "@/components/sidebar/ContextMenu.vue";
import type { MenuItem } from "@/components/sidebar/ContextMenu.vue";

const { t } = useI18n();
const appWindow = getCurrentWindow();
const isMac = navigator.platform.toUpperCase().includes("MAC");

function handleTitlebarMouseDown(e: MouseEvent) {
  if (e.button !== 0) return;
  if ((e.target as HTMLElement).closest("button")) return;
  if ((e.target as HTMLElement).closest(".tab-btn")) return;
  if ((e.target as HTMLElement).closest(".window-ctrl")) return;

  if (e.detail >= 2) {
    appWindow.toggleMaximize();
  } else {
    appWindow.startDragging();
  }
}

function handleWindowControl(action: "minimize" | "maximize" | "close") {
  if (action === "minimize") appWindow.minimize();
  else if (action === "maximize") appWindow.toggleMaximize();
  else appWindow.close();
}

const props = defineProps<{
  sidebarOpen?: boolean;
  sidebarWidth?: number;
}>();

// macOS: when sidebar open, match actual sidebar width; otherwise traffic light width (78px)
// Windows/Linux: no spacer needed
const spacerWidth = computed(() => {
  if (!isMac) return "0px";
  return props.sidebarOpen ? `${props.sidebarWidth ?? 240}px` : "78px";
});

const emit = defineEmits<{
  (e: "settings"): void;
  (e: "toggle-ai"): void;
  (e: "open-ai"): void;
  (e: "new-host"): void;
  (e: "reconnect", sessionId: string): void;
}>();

interface EngineStatus {
  binary_ready: boolean;
  running: boolean;
  port: number | null;
  loaded_model: string | null;
}
interface DownloadedModel { id: string; path: string; size: number }

const sessionStore = useSessionStore();
const aiStore = useAiStore();

const localAiRunning = ref(false);
const localAiAvailable = ref(false);
const localAiStarting = ref(false);

async function refreshEngineStatus() {
  try {
    const [status, models] = await Promise.all([
      tauriInvoke<EngineStatus>("local_ai_engine_status"),
      tauriInvoke<DownloadedModel[]>("local_ai_list_downloaded").catch(() => [] as DownloadedModel[]),
    ]);
    localAiRunning.value = status.running;
    // Show button if: engine binary exists OR models downloaded OR a local provider is configured
    localAiAvailable.value = status.binary_ready || models.length > 0
      || aiStore.providers.some((p) => p.providerType === "local");
  } catch {
    localAiRunning.value = false;
  }
}

async function quickStartEngine() {
  localAiStarting.value = true;

  // Immediately open AI panel
  emit("open-ai");

  const models = await tauriInvoke<DownloadedModel[]>("local_ai_list_downloaded").catch(() => [] as DownloadedModel[]);
  if (models.length === 0) {
    localAiStarting.value = false;
    emit("settings");
    return;
  }

  const model = models[0];
  const modelName = model.id;
  const msgId = crypto.randomUUID();

  // Push "starting" system message into AI panel
  aiStore.messages.push({
    id: msgId,
    role: "system",
    content: `engine_starting:${modelName}`,
    timestamp: new Date().toISOString(),
  });

  try {
    await tauriInvoke("local_ai_start_engine", { modelPath: model.path });
    await refreshEngineStatus();

    // Replace starting message with success
    const idx = aiStore.messages.findIndex((m) => m.id === msgId);
    if (idx !== -1) {
      aiStore.messages[idx] = {
        ...aiStore.messages[idx],
        content: `engine_started:${modelName}`,
      };
    }
  } catch (e) {
    // Replace starting message with error
    const idx = aiStore.messages.findIndex((m) => m.id === msgId);
    if (idx !== -1) {
      aiStore.messages[idx] = {
        ...aiStore.messages[idx],
        content: `engine_error:${e}`,
      };
    }
  } finally {
    localAiStarting.value = false;
  }
}

const _unlisteners: Array<() => void> = [];
onMounted(async () => {
  await aiStore.loadProviders();
  await refreshEngineStatus();
  _unlisteners.push(await tauriListen("local-ai://status", () => refreshEngineStatus()));
});
onUnmounted(() => _unlisteners.forEach((fn) => fn()));
function onTabClick(sessionId: string) {
  sessionStore.setActive(sessionId);
}

function onTabClose(e: MouseEvent, sessionId: string) {
  e.stopPropagation();
  sessionStore.disconnect(sessionId);
}

function openLocalTerminal() {
  sessionStore.openLocalTerminal();
}

// ── Inline rename ──
const renamingTabKey = ref<string | null>(null);
const renameValue = ref("");
const renameInputRef = ref<HTMLInputElement | null>(null);

async function startRename(tabKey: string) {
  const tab = sessionStore.tabs.find((t) => t.tabKey === tabKey);
  if (!tab) return;
  renameValue.value = tab.title;
  renamingTabKey.value = tabKey;
  await nextTick();
  renameInputRef.value?.focus();
  renameInputRef.value?.select();
}

function commitRename() {
  const trimmed = renameValue.value.trim();
  if (trimmed && renamingTabKey.value) {
    const tab = sessionStore.tabs.find((t) => t.tabKey === renamingTabKey.value);
    if (tab) tab.title = trimmed;
  }
  renamingTabKey.value = null;
}

function cancelRename() {
  renamingTabKey.value = null;
}

// ── Tab context menu ──
const ctxVisible = ref(false);
const ctxX = ref(0);
const ctxY = ref(0);
const ctxSessionId = ref("");

const ctxItems = computed<MenuItem[]>(() => [
  { label: t("tab.close"), action: "close" },
  { label: t("tab.closeOthers"), action: "close-others" },
  { label: t("sidebar.newConnection"), action: "new-host", divided: true },
  { label: t("tab.duplicate"), action: "duplicate" },
  { label: t("tab.rename"), action: "rename", divided: true },
  { label: t("tab.reconnect"), action: "reconnect" },
  { label: t("tab.reconnectAll"), action: "reconnect-all" },
]);

function onTabContextMenu(e: MouseEvent, sessionId: string) {
  e.preventDefault();
  ctxSessionId.value = sessionId;
  ctxX.value = e.clientX;
  ctxY.value = e.clientY;
  ctxVisible.value = true;
}

async function onCtxSelect(action: string) {
  const sid = ctxSessionId.value;
  const tab = sessionStore.tabs.find((t) => t.sessionId === sid);

  if (action === "close") {
    sessionStore.disconnect(sid);
  } else if (action === "close-others") {
    const others = sessionStore.tabs.filter((t) => t.sessionId !== sid);
    for (const t of others) {
      sessionStore.disconnect(t.sessionId);
    }
    sessionStore.setActive(sid);
  } else if (action === "new-host") {
    emit("new-host");
  } else if (action === "duplicate") {
    // Re-connect the same server
    const session = sessionStore.sessions.get(sid);
    if (session) {
      sessionStore.connect(session.serverId, session.serverName);
    }
  } else if (action === "rename") {
    if (!tab) return;
    startRename(tab.tabKey);
  } else if (action === "reconnect") {
    emit("reconnect", sid);
  } else if (action === "reconnect-all") {
    for (const t of [...sessionStore.tabs]) {
      const s = sessionStore.sessions.get(t.sessionId);
      if (s && s.type === "ssh") {
        emit("reconnect", t.sessionId);
      }
    }
  }
}
</script>

<template>
  <div class="titlebar h-9 flex items-center shrink-0 overflow-x-auto select-none"
       style="background: var(--tm-bg-surface); border-bottom: 1px solid var(--tm-border)"
       @mousedown="handleTitlebarMouseDown"
  >
    <!-- Left spacer: adapts to sidebar width on macOS, hidden on other platforms -->
    <div
      class="shrink-0 h-full transition-all duration-200"
      :style="{ width: spacerWidth }"
    />

    <!-- Tabs -->
    <button
      v-for="tab in sessionStore.tabs"
      :key="tab.tabKey"
      class="tab-btn group flex items-center gap-1.5 px-3 h-full text-xs transition-colors shrink-0 w-[120px]"
           :class="tab.active ? 'tm-tab-active border-b-2 border-b-primary-500' : 'tm-tab-inactive'"
      @click="onTabClick(tab.sessionId)"
      @mousedown.middle.prevent="sessionStore.disconnect(tab.sessionId)"
      @contextmenu="onTabContextMenu($event, tab.sessionId)"
    >
      <!-- Status dot -->
      <span
        class="w-1.5 h-1.5 rounded-full shrink-0"
        :class="{
          'bg-green-500': sessionStore.sessions.get(tab.sessionId)?.status === 'connected',
          'bg-yellow-500 animate-pulse': ['connecting', 'reconnecting'].includes(sessionStore.sessions.get(tab.sessionId)?.status ?? ''),
          'bg-gray-500': sessionStore.sessions.get(tab.sessionId)?.status === 'disconnected',
          'bg-red-500': sessionStore.sessions.get(tab.sessionId)?.status === 'error',
        }"
      />

      <!-- Inline rename or title -->
      <input
        v-if="renamingTabKey === tab.tabKey"
        ref="renameInputRef"
        v-model="renameValue"
        class="w-16 min-w-0 flex-1 text-xs px-0.5 py-0 rounded outline-none"
        style="background: var(--tm-input-bg); color: var(--tm-text-primary); border: 1px solid var(--tm-input-border)"
        @blur="commitRename"
        @keydown.enter="commitRename"
        @keydown.escape="cancelRename"
        @click.stop
        @dblclick.stop
      />
      <span v-else class="truncate flex-1 text-left">{{ tab.title }}</span>

      <!-- Close button -->
      <el-icon
        :size="12"
        class="shrink-0 ml-auto opacity-0 group-hover:opacity-100 hover:text-red-400 transition-opacity"
        @click.stop="onTabClose($event, tab.sessionId)"
      >
        <Close />
      </el-icon>
    </button>

    <!-- New local terminal [+] -->
    <button
      class="tab-btn tm-icon-btn px-2 h-full transition-colors shrink-0"
      :title="$t('terminal.openLocalTerminal')"
      @click="openLocalTerminal"
    >
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
        <path d="M12 5v14M5 12h14" />
      </svg>
    </button>

    <!-- Empty fill -->
    <div class="flex-1 h-full" />

    <!-- Local AI engine indicator (available but not running) -->
    <button
      v-if="localAiAvailable && !localAiRunning"
      class="flex items-center gap-1 px-2 h-full text-[10px] shrink-0 transition-colors"
      :class="localAiStarting ? 'text-yellow-400 cursor-wait' : 'text-orange-400 hover:text-orange-300 cursor-pointer'"
      :disabled="localAiStarting"
      @click="quickStartEngine"
    >
      <span v-if="localAiStarting" class="animate-spin">&#x23F3;</span>
      <span v-else>&#x26A0;</span>
      <span>{{ t("localAi.engineStopped") }}</span>
      <span class="font-medium">{{ t("localAi.start") }}</span>
    </button>

    <!-- AI toggle -->
    <button
      class="tm-icon-btn px-2 h-full transition-colors shrink-0"
      :title="$t('settings.aiConfig')"
      @click="emit('toggle-ai')"
    >
      <span class="text-sm leading-none">&#x2728;</span>
    </button>

    <!-- Settings -->
    <button
      class="tm-icon-btn px-2 h-full transition-colors shrink-0"      :title="$t('settings.title')"
      @click="emit('settings')"
    >
      <el-icon :size="14"><Setting /></el-icon>
    </button>

    <!-- Window controls for Windows/Linux (no native titlebar) -->
    <template v-if="!isMac">
      <div class="w-px h-4 mx-1 shrink-0" style="background: var(--tm-border)" />
      <button
        class="window-ctrl hover:bg-white/10 w-[46px] h-full flex items-center justify-center transition-colors"
        @click="handleWindowControl('minimize')"
      >
        <svg width="10" height="1" viewBox="0 0 10 1" fill="currentColor"><rect width="10" height="1" /></svg>
      </button>
      <button
        class="window-ctrl hover:bg-white/10 w-[46px] h-full flex items-center justify-center transition-colors"
        @click="handleWindowControl('maximize')"
      >
        <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1"><rect x="0.5" y="0.5" width="9" height="9" /></svg>
      </button>
      <button
        class="window-ctrl hover:bg-red-500 hover:text-white w-[46px] h-full flex items-center justify-center transition-colors"
        @click="handleWindowControl('close')"
      >
        <svg width="10" height="10" viewBox="0 0 10 10" stroke="currentColor" stroke-width="1.2"><line x1="0" y1="0" x2="10" y2="10" /><line x1="10" y1="0" x2="0" y2="10" /></svg>
      </button>
    </template>

    <!-- Tab context menu -->
    <ContextMenu
      v-if="ctxVisible"
      :items="ctxItems"
      :x="ctxX"
      :y="ctxY"
      @select="onCtxSelect"
      @close="ctxVisible = false"
    />
  </div>
</template>
