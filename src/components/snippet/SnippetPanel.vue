<script setup lang="ts">
import { ref, computed, onMounted, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Search, Plus, FolderOpened } from "@element-plus/icons-vue";
import { useSnippetStore } from "@/stores/snippetStore";
import { useSessionStore } from "@/stores/sessionStore";
import { useTeamStore } from "@/stores/teamStore";
import { tauriInvoke } from "@/utils/tauri";
import { getTerminalEntry } from "@/utils/terminalRegistry";
import SnippetItem from "./SnippetItem.vue";
import SnippetForm from "./SnippetForm.vue";
import type { Snippet } from "@/types/snippet";

const { t } = useI18n();
const snippetStore = useSnippetStore();
const sessionStore = useSessionStore();
const teamStore = useTeamStore();

import { useTeamPermission } from "@/composables/useTeamPermission";
const { can } = useTeamPermission();

// ── Team filter state ──
const snippetFilter = ref<"all" | "private" | "team">("all");

// Derived from all snippets (not folder-filtered) so section headers always show
const hasPrivateSnippets = computed(() =>
  snippetStore.snippets.some((s) => !s.shared && !s.teamId),
);
const hasTeamSnippets = computed(() =>
  snippetStore.snippets.some((s) => !!s.shared || !!s.teamId),
);

// In "all" mode when team joined, render two sections with a divider
const showSplitView = computed(() =>
  teamStore.isJoined && snippetFilter.value === "all",
);

const visibleSnippets = computed(() => {
  if (!teamStore.isJoined) return snippetStore.filteredSnippets;
  if (snippetFilter.value === "private") return snippetStore.privateSnippets;
  if (snippetFilter.value === "team") return snippetStore.teamSnippets;
  // "all" — handled by split view, but return all for empty-state check
  return snippetStore.filteredSnippets;
});

// ── Local state ─────────────────────────────────────────────
const searchInput = ref("");
const formVisible = ref(false);
const editingSnippet = ref<Snippet | undefined>(undefined);
let debounceTimer: ReturnType<typeof setTimeout> | null = null;

// ── Search with 300ms debounce ──────────────────────────────
watch(searchInput, (val) => {
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    snippetStore.searchQuery = val;
    snippetStore.loadSnippets();
  }, 300);
});

// ── Folder tab selection ────────────────────────────────────
function selectFolder(folderId: string | null) {
  snippetStore.setFolder(folderId);
  snippetStore.loadSnippets();
}

// ── CRUD handlers ───────────────────────────────────────────
function openCreate() {
  editingSnippet.value = undefined;
  formVisible.value = true;
}

function openEdit(snippet: Snippet) {
  // Owned snippets (no teamId) are always editable; team-received require SnippetEdit cap
  if (snippet.teamId && !can("SnippetEdit")) return;
  editingSnippet.value = snippet;
  formVisible.value = true;
}

function onSaved() {
  formVisible.value = false;
  editingSnippet.value = undefined;
}

async function onDelete(snippet: Snippet) {
  if (snippet.teamId && !can("SnippetDelete")) return;
  await snippetStore.deleteSnippet(snippet.id);
}

async function onSetShared(snippet: Snippet, shared: boolean) {
  await snippetStore.setShared(snippet.id, shared);
}

async function onMakeLocal(snippet: Snippet) {
  await snippetStore.makeLocal(snippet.id);
}

async function onToggleFavorite(snippet: Snippet) {
  await snippetStore.updateSnippet(snippet.id, {
    title: snippet.title,
    command: snippet.command,
    description: snippet.description,
    tags: [...snippet.tags],
    folderId: snippet.folderId,
    isFavorite: !snippet.isFavorite,
  });
}

async function onExecute(snippet: Snippet) {
  // Execute is always allowed for owned snippets; team-received require SnippetExecute cap
  if (snippet.teamId && !can("SnippetExecute")) return;
  const sid = sessionStore.activeSessionId;
  if (!sid || sid.startsWith("connecting-")) return;
  const text = snippet.command.trim();
  const bytes = new TextEncoder().encode(text);
  const writeCmd = sid.startsWith("local-") ? "local_pty_write" : "ssh_write";
  await tauriInvoke(writeCmd, { sessionId: sid, data: Array.from(bytes) }).catch(() => {});
  // Focus terminal so user can immediately press Enter to execute
  getTerminalEntry(sid)?.terminal.focus();
}

// ── Init ────────────────────────────────────────────────────
onMounted(() => {
  snippetStore.loadSnippets();
  snippetStore.loadFolders();
});
</script>

<template>
  <div
    class="flex flex-col h-full select-none"
    style="background: var(--tm-sidebar-bg)"
  >
    <!-- Header: search + add button -->
    <div
      class="flex items-center gap-1.5 px-2 py-1.5 shrink-0"
      style="border-bottom: 1px solid var(--tm-border)"
    >
      <div
        class="flex-1 flex items-center gap-1 rounded px-2 py-1"
        style="background: var(--tm-input-bg); border: 1px solid var(--tm-input-border)"
      >
        <el-icon :size="12" style="color: var(--tm-text-muted)">
          <Search />
        </el-icon>
        <input
          v-model="searchInput"
          class="flex-1 text-xs bg-transparent outline-none"
          style="color: var(--tm-text-primary)"
          :placeholder="t('snippet.search')"
        />
      </div>
      <button
        v-if="!teamStore.isJoined || can('SnippetCreate')"
        class="tm-icon-btn p-1.5 rounded transition-colors shrink-0"
        :title="t('snippet.create')"
        @click="openCreate"
      >
        <el-icon :size="14"><Plus /></el-icon>
      </button>
    </div>

    <!-- Team filter tabs (only when joined) -->
    <div
      v-if="teamStore.isJoined"
      class="flex items-center gap-1 px-2 py-1 shrink-0"
      style="border-bottom: 1px solid var(--tm-border)"
    >
      <button
        v-for="f in (['all', 'private', 'team'] as const)"
        :key="f"
        class="px-2 py-0.5 rounded text-[10px] transition-colors"
        :class="snippetFilter === f ? 'bg-primary-500/20 text-primary-400' : 'text-gray-500 hover:text-gray-300'"
        @click="snippetFilter = f"
      >
        {{ t(`sidebar.filter_${f}`) }}
      </button>
    </div>

    <!-- Folder tabs (hidden when team mode is active) -->
    <div
      v-if="!teamStore.isJoined"
      class="flex items-stretch overflow-x-auto shrink-0"
      style="border-bottom: 1px solid var(--tm-border)"
    >
      <button
        class="snippet-folder-tab"
        :class="{ 'snippet-folder-tab-active': snippetStore.currentFolderId === null }"
        @click="selectFolder(null)"
      >
        {{ t('snippet.allFolder') }}
      </button>
      <button
        v-for="folder in snippetStore.folders"
        :key="folder.id"
        class="snippet-folder-tab flex items-center gap-1"
        :class="{ 'snippet-folder-tab-active': snippetStore.currentFolderId === folder.id }"
        @click="selectFolder(folder.id)"
      >
        <el-icon :size="10"><FolderOpened /></el-icon>
        {{ folder.name }}
      </button>
    </div>

    <!-- Snippet list -->
    <div class="flex-1 overflow-y-auto px-1 py-1">

      <!-- Split view: "all" tab when team joined — private section + divider + team section -->
      <template v-if="showSplitView">
        <!-- Private snippets -->
        <SnippetItem
          v-for="snippet in snippetStore.privateSnippets"
          :key="snippet.id"
          :snippet="snippet"
          :can-execute="!snippet.teamId || can('SnippetExecute')"
          @execute="onExecute"
          @edit="openEdit"
          @delete="onDelete"
          @toggle-favorite="onToggleFavorite"
          @set-shared="onSetShared"
          @make-local="onMakeLocal"
        />

        <!-- Divider (only when both sections have content) -->
        <div
          v-if="hasPrivateSnippets && hasTeamSnippets"
          class="mx-2 my-1"
          style="border-top: 1px solid var(--tm-border)"
        />

        <!-- Team section header -->
        <div
          v-if="hasTeamSnippets"
          class="flex items-center gap-1.5 px-2 py-1"
          style="color: #60a5fa"
        >
          <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
          <span class="text-[10px] font-medium">{{ t("sidebar.teamServers") }}</span>
        </div>

        <!-- Team snippets -->
        <SnippetItem
          v-for="snippet in snippetStore.teamSnippets"
          :key="snippet.id"
          :snippet="snippet"
          :can-execute="!snippet.teamId || can('SnippetExecute')"
          @execute="onExecute"
          @edit="openEdit"
          @delete="onDelete"
          @toggle-favorite="onToggleFavorite"
          @set-shared="onSetShared"
          @make-local="onMakeLocal"
        />
      </template>

      <!-- Single-section view (private tab, team tab, or no team) -->
      <template v-else-if="visibleSnippets.length > 0">
        <SnippetItem
          v-for="snippet in visibleSnippets"
          :key="snippet.id"
          :snippet="snippet"
          :can-execute="!snippet.teamId || can('SnippetExecute')"
          @execute="onExecute"
          @edit="openEdit"
          @delete="onDelete"
          @toggle-favorite="onToggleFavorite"
          @set-shared="onSetShared"
          @make-local="onMakeLocal"
        />
      </template>

      <!-- Empty state (shown when no snippets at all) -->
      <div
        v-if="!showSplitView && visibleSnippets.length === 0"
        class="flex flex-col items-center justify-center py-12 gap-2"
      >
        <span class="text-xs" style="color: var(--tm-text-muted)">
          {{ searchInput ? t('snippet.noResults') : t('snippet.empty') }}
        </span>
        <button
          v-if="!searchInput && snippetFilter !== 'team'"
          class="text-xs px-3 py-1 rounded transition-colors"
          style="color: var(--el-color-primary, #409eff)"
          @click="openCreate"
        >
          {{ t('snippet.createFirst') }}
        </button>
      </div>
    </div>

    <!-- Form dialog -->
    <SnippetForm
      v-model="formVisible"
      :snippet="editingSnippet"
      @saved="onSaved"
    />
  </div>
</template>

<style scoped>
.snippet-folder-tab {
  padding: 4px 10px;
  font-size: 11px;
  white-space: nowrap;
  border: none;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
  background: transparent;
  color: var(--tm-text-muted);
  cursor: pointer;
  transition: color 0.15s;
}
.snippet-folder-tab:hover {
  color: var(--tm-text-primary);
}
.snippet-folder-tab-active {
  color: var(--el-color-primary, #409eff);
  border-bottom-color: var(--el-color-primary, #409eff);
}
</style>
