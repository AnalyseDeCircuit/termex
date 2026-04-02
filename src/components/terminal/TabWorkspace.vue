<script setup lang="ts">
import { ref, computed, watch, nextTick } from "vue";
import { useI18n } from "vue-i18n";
import { useSettingsStore } from "@/stores/settingsStore";
import { useSessionStore } from "@/stores/sessionStore";
import { useTabSftp } from "@/composables/useTabSftp";
import { useDragLayout } from "@/composables/useDragLayout";
import TerminalView from "./TerminalView.vue";
import SftpPanel from "@/components/sftp/SftpPanel.vue";
import TransfersPanel from "@/components/sftp/TransfersPanel.vue";

const props = defineProps<{
  sessionId: string;
}>();

const { t } = useI18n();
const settingsStore = useSettingsStore();
const sessionStore = useSessionStore();

const terminalViewRef = ref<InstanceType<typeof TerminalView>>();
const workspaceRef = ref<HTMLElement>();
const activeSubTab = ref<"ssh" | "sftp" | "transfers">("ssh");
const splitSubTab = ref<"sftp" | "transfers">("sftp");

const sftpLayout = computed(() => settingsStore.sftpLayout ?? "tabs");

// Per-tab SFTP state (provided to child components via inject)
const tabSftp = useTabSftp();
const { dragging, dropTarget, startDrag } = useDragLayout();

const session = computed(() => sessionStore.sessions.get(props.sessionId));
const isConnected = computed(() => session.value?.status === "connected");

// Open SFTP lazily on sub-tab switch
watch(activeSubTab, async (tab) => {
  if (tab === "ssh") {
    await nextTick();
    terminalViewRef.value?.fit();
  } else if (tab === "sftp") {
    await ensureSftpOpen();
  }
});

// When layout changes from tabs to split, open SFTP if needed
watch(sftpLayout, async (layout) => {
  if (layout !== "tabs") {
    await ensureSftpOpen();
    activeSubTab.value = "ssh"; // reset sub-tab in case it was on sftp
  }
  await nextTick();
  terminalViewRef.value?.fit();
});

// In split mode, auto-connect SFTP when SSH becomes connected
watch(isConnected, async (connected) => {
  if (connected && sftpLayout.value !== "tabs") {
    await ensureSftpOpen();
  }
});

async function ensureSftpOpen() {
  if (!tabSftp.connected.value && isConnected.value) {
    await tabSftp.openSftp(props.sessionId, session.value?.serverName ?? "");
  }
}

// SFTP connecting state (SSH connected but SFTP channel not yet open)
const sftpLoading = computed(() => isConnected.value && !tabSftp.connected.value);

// Transfer badge count
const activeTransferCount = computed(() => tabSftp.activeTransfers.value.length);

// Sub-tab config for tabs mode
const subTabs = computed(() => [
  { key: "ssh" as const, label: "SSH", badge: 0 },
  { key: "sftp" as const, label: "SFTP", badge: 0 },
  { key: "transfers" as const, label: t("sftp.transfers"), badge: activeTransferCount.value },
]);

function switchSubTab(key: "ssh" | "sftp" | "transfers") {
  activeSubTab.value = key;
}

// Drag handler (unified for all modes)
function handleSftpDragStart(e: MouseEvent) {
  if (workspaceRef.value) {
    startDrag(e, workspaceRef.value);
  }
}

// Split resize
const splitRatio = ref(0.5);
const resizing = ref(false);

function startSplitResize(e: MouseEvent) {
  e.preventDefault();
  resizing.value = true;

  function onMove(e: MouseEvent) {
    if (!workspaceRef.value) return;
    const rect = workspaceRef.value.getBoundingClientRect();
    if (sftpLayout.value === "right") {
      const pos = e.clientX - rect.left;
      splitRatio.value = Math.max(0.2, Math.min(0.8, pos / rect.width));
    } else {
      const pos = e.clientY - rect.top;
      splitRatio.value = Math.max(0.2, Math.min(0.8, pos / rect.height));
    }
  }

  function onUp() {
    resizing.value = false;
    window.removeEventListener("mousemove", onMove);
    window.removeEventListener("mouseup", onUp);
    nextTick(() => terminalViewRef.value?.fit());
  }

  window.addEventListener("mousemove", onMove);
  window.addEventListener("mouseup", onUp);
}

defineExpose({
  fit: () => terminalViewRef.value?.fit(),
  dispose: () => terminalViewRef.value?.dispose(),
  openSearch: () => terminalViewRef.value?.openSearch(),
  get search() {
    return terminalViewRef.value?.search;
  },
});
</script>

<template>
  <div ref="workspaceRef" class="w-full h-full flex flex-col overflow-hidden relative">
    <!-- ═══ Tabs Mode ═══ -->
    <template v-if="sftpLayout === 'tabs'">
      <!-- Sub-tab bar -->
      <div
        class="workspace-tab-bar flex items-stretch h-6 shrink-0 px-1 gap-0.5"
        style="background: var(--tm-bg-surface); border-bottom: 1px solid var(--tm-border)"
      >
        <button
          v-for="tab in subTabs"
          :key="tab.key"
          class="workspace-tab relative"
          :class="{ 'workspace-tab-active': activeSubTab === tab.key }"
          @click="switchSubTab(tab.key)"
          @mousedown.prevent="tab.key === 'sftp' ? handleSftpDragStart($event) : undefined"
        >
          {{ tab.label }}
          <span
            v-if="tab.badge > 0"
            class="absolute -top-0.5 -right-1 w-3.5 h-3.5 bg-red-500 rounded-full text-white text-[8px] flex items-center justify-center font-bold"
          >
            {{ tab.badge }}
          </span>
        </button>
      </div>

      <!-- Content -->
      <div class="flex-1 min-h-0 relative">
        <TerminalView
          ref="terminalViewRef"
          :session-id="sessionId"
          class="absolute inset-0"
          :style="{ display: activeSubTab === 'ssh' ? '' : 'none' }"
        />
        <div v-if="activeSubTab === 'sftp'" class="absolute inset-0">
          <SftpPanel v-if="tabSftp.connected.value" />
          <div v-else class="w-full h-full flex items-center justify-center" style="color: var(--tm-text-muted)">
            <div class="text-center text-xs">
              <template v-if="isConnected"><div class="animate-pulse">{{ t("sftp.connecting") }}</div></template>
              <template v-else>{{ t("sftp.notConnected") }}</template>
            </div>
          </div>
        </div>
        <div v-if="activeSubTab === 'transfers'" class="absolute inset-0">
          <TransfersPanel />
        </div>
      </div>
    </template>

    <!-- ═══ Right Split ═══ -->
    <template v-else-if="sftpLayout === 'right'">
      <div class="flex-1 min-h-0 flex">
        <TerminalView
          ref="terminalViewRef"
          :session-id="sessionId"
          :style="{ width: `${splitRatio * 100}%` }"
          class="min-w-0 shrink-0"
        />
        <!-- Resize handle -->
        <div
          class="w-1 shrink-0 cursor-col-resize transition-colors hover:bg-blue-500"
          style="background-color: var(--tm-border)"
          @mousedown="startSplitResize"
        />
        <!-- SFTP/Transfers panel -->
        <div class="flex-1 min-w-0 flex flex-col">
          <div
            class="workspace-tab-bar flex items-stretch h-6 shrink-0 px-1 gap-0.5"
            style="background: var(--tm-bg-surface); border-bottom: 1px solid var(--tm-border)"
          >
            <button
              class="workspace-tab relative"
              :class="{ 'workspace-tab-active': splitSubTab === 'sftp' }"
              @click="splitSubTab = 'sftp'"
              @mousedown.prevent="handleSftpDragStart($event)"
            >
              SFTP
            </button>
            <button
              class="workspace-tab relative"
              :class="{ 'workspace-tab-active': splitSubTab === 'transfers' }"
              @click="splitSubTab = 'transfers'"
            >
              {{ t("sftp.transfers") }}
              <span
                v-if="activeTransferCount > 0"
                class="absolute -top-0.5 -right-1 w-3.5 h-3.5 bg-red-500 rounded-full text-white text-[8px] flex items-center justify-center font-bold"
              >
                {{ activeTransferCount }}
              </span>
            </button>
          </div>
          <div class="flex-1 min-h-0 relative">
            <div v-show="splitSubTab === 'sftp'" class="absolute inset-0">
              <SftpPanel v-if="tabSftp.connected.value" />
              <div v-else class="w-full h-full flex items-center justify-center" style="color: var(--tm-text-muted)">
                <div class="text-center text-xs">
                  <div v-if="sftpLoading" class="animate-pulse">{{ t("sftp.connecting") }}</div>
                  <div v-else>{{ t("sftp.notConnected") }}</div>
                </div>
              </div>
            </div>
            <div v-show="splitSubTab === 'transfers'" class="absolute inset-0">
              <TransfersPanel />
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- ═══ Bottom Split ═══ -->
    <template v-else-if="sftpLayout === 'bottom'">
      <div class="flex-1 min-h-0 flex flex-col">
        <TerminalView
          ref="terminalViewRef"
          :session-id="sessionId"
          :style="{ height: `${splitRatio * 100}%` }"
          class="min-h-0 shrink-0"
        />
        <!-- Resize handle -->
        <div
          class="h-1 shrink-0 cursor-row-resize transition-colors hover:bg-blue-500"
          style="background-color: var(--tm-border)"
          @mousedown="startSplitResize"
        />
        <!-- SFTP/Transfers panel -->
        <div class="flex-1 min-h-0 flex flex-col">
          <div
            class="workspace-tab-bar flex items-stretch h-6 shrink-0 px-1 gap-0.5"
            style="background: var(--tm-bg-surface); border-bottom: 1px solid var(--tm-border)"
          >
            <button
              class="workspace-tab relative"
              :class="{ 'workspace-tab-active': splitSubTab === 'sftp' }"
              @click="splitSubTab = 'sftp'"
              @mousedown.prevent="handleSftpDragStart($event)"
            >
              SFTP
            </button>
            <button
              class="workspace-tab relative"
              :class="{ 'workspace-tab-active': splitSubTab === 'transfers' }"
              @click="splitSubTab = 'transfers'"
            >
              {{ t("sftp.transfers") }}
              <span
                v-if="activeTransferCount > 0"
                class="absolute -top-0.5 -right-1 w-3.5 h-3.5 bg-red-500 rounded-full text-white text-[8px] flex items-center justify-center font-bold"
              >
                {{ activeTransferCount }}
              </span>
            </button>
          </div>
          <div class="flex-1 min-h-0 relative">
            <div v-show="splitSubTab === 'sftp'" class="absolute inset-0">
              <SftpPanel v-if="tabSftp.connected.value" />
              <div v-else class="w-full h-full flex items-center justify-center" style="color: var(--tm-text-muted)">
                <div class="text-center text-xs">
                  <div v-if="sftpLoading" class="animate-pulse">{{ t("sftp.connecting") }}</div>
                  <div v-else>{{ t("sftp.notConnected") }}</div>
                </div>
              </div>
            </div>
            <div v-show="splitSubTab === 'transfers'" class="absolute inset-0">
              <TransfersPanel />
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- ═══ Drop zone indicators (during drag) ═══ -->
    <template v-if="dragging">
      <div class="absolute inset-0 pointer-events-none z-50">
        <!-- Center = restore to tabs (only in split modes) -->
        <div
          v-if="sftpLayout !== 'tabs'"
          class="absolute left-0 top-0 transition-colors"
          :style="{
            width: sftpLayout === 'right' ? '67%' : '100%',
            height: sftpLayout === 'bottom' ? '67%' : '100%',
          }"
          :class="dropTarget === 'tabs' ? 'bg-green-500/20 border-2 border-green-400' : ''"
        />
        <!-- Right zone -->
        <div
          class="absolute right-0 top-0 bottom-0 w-1/3 transition-colors"
          :class="dropTarget === 'right' ? 'bg-blue-500/30 border-l-2 border-blue-400' : 'bg-blue-500/10'"
        />
        <!-- Bottom zone -->
        <div
          class="absolute bottom-0 left-0 right-0 h-1/3 transition-colors"
          :class="dropTarget === 'bottom' ? 'bg-blue-500/30 border-t-2 border-blue-400' : 'bg-blue-500/10'"
        />
      </div>
    </template>
  </div>
</template>

<style scoped>
.workspace-tab {
  font-size: 10px;
  padding: 0 10px;
  height: 100%;
  display: flex;
  align-items: center;
  border: none;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
  background: transparent;
  color: var(--tm-text-muted);
  cursor: pointer;
  transition: color 0.15s;
  white-space: nowrap;
}

.workspace-tab:hover {
  color: var(--tm-text-secondary);
}

.workspace-tab-active {
  color: var(--tm-text-primary);
  border-bottom-color: var(--el-color-primary, #409eff);
}
</style>
