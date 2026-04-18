<script setup lang="ts">
import { ref, computed } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage, ElMessageBox } from "element-plus";
import { Plus } from "@element-plus/icons-vue";
import { useServerStore } from "@/stores/serverStore";
import { useSessionStore } from "@/stores/sessionStore";
import { useTeamStore } from "@/stores/teamStore";
import { useConfigExport } from "@/composables/useConfigExport";
import type { Server, ServerInput } from "@/types/server";
import ServerGroup from "./ServerGroup.vue";
import ServerItem from "./ServerItem.vue";
import ContextMenu from "./ContextMenu.vue";
import type { MenuItem } from "./ContextMenu.vue";
import { useTeamPermission } from "@/composables/useTeamPermission";

const emit = defineEmits<{
  (e: "new-host"): void;
  (e: "edit-server", id: string): void;
}>();

const { can } = useTeamPermission();
const { exportConfig, importConfig } = useConfigExport();

const { t } = useI18n();
const serverStore = useServerStore();
const sessionStore = useSessionStore();
const teamStore = useTeamStore();
const rootDragOver = ref(false);
const rootRef = ref<HTMLElement | null>(null);
let dragOverCount = 0;

// ── Filter state (only active when joined a team) ──
const serverFilter = ref<"all" | "private" | "team">("all");

// ── Computed: private vs team split ──

/** A server belongs to the "team" view if it is shared (by me) or received from team. */
function isTeamVisible(s: { shared?: boolean; teamId?: string | null }): boolean {
  return !!s.shared || !!s.teamId;
}

/** Groups with servers filtered to private-only (not shared, not received). */
const privateGroupTree = computed(() =>
  serverStore.groups
    .filter((g) => !g.parentId)
    .map((g) => ({
      ...g,
      children: serverStore.groups.filter((c) => c.parentId === g.id),
      servers: serverStore.filteredServers.filter(
        (s) => s.groupId === g.id && !isTeamVisible(s),
      ),
    }))
    .filter((g) => g.servers.length > 0),
);

/** Ungrouped private servers (not shared, not received). */
const privateUngrouped = computed(() =>
  serverStore.filteredServers.filter((s) => !s.groupId && !isTeamVisible(s)),
);

/** Groups with servers that are shared-by-me or received from team. */
const teamGroupTree = computed(() =>
  serverStore.groups
    .filter((g) => !g.parentId)
    .map((g) => ({
      ...g,
      children: serverStore.groups.filter((c) => c.parentId === g.id),
      servers: serverStore.filteredServers.filter(
        (s) => s.groupId === g.id && isTeamVisible(s),
      ),
    }))
    .filter((g) => g.servers.length > 0),
);

/** Ungrouped servers that are shared-by-me or received from team. */
const teamUngrouped = computed(() =>
  serverStore.filteredServers.filter((s) => !s.groupId && isTeamVisible(s)),
);

const hasPrivate = computed(
  () => privateGroupTree.value.length > 0 || privateUngrouped.value.length > 0,
);

const hasTeam = computed(
  () => teamGroupTree.value.length > 0 || teamUngrouped.value.length > 0,
);

const showPrivate = computed(
  () => serverFilter.value === "all" || serverFilter.value === "private",
);

const showTeam = computed(
  () =>
    (serverFilter.value === "all" || serverFilter.value === "team") &&
    teamStore.isJoined,
);

// ── Empty-state guard ──
const hasVisibleContent = computed(() => {
  if (!teamStore.isJoined) {
    return serverStore.groups.length > 0 || serverStore.servers.length > 0;
  }
  if (serverFilter.value === "private") return hasPrivate.value;
  if (serverFilter.value === "team") return hasTeam.value;
  return serverStore.groups.length > 0 || serverStore.servers.length > 0;
});

async function handleConnect(server: Server) {
  try {
    await sessionStore.connect(server.id, server.name);
  } catch (e) {
    ElMessage.error(`${server.name}: ${String(e)}`);
  }
}

function onRootDragEnter(e: DragEvent) {
  if (!e.dataTransfer?.types.includes("text/plain")) return;
  dragOverCount++;
  rootDragOver.value = true;
}

function onRootDragOver(e: DragEvent) {
  if (e.dataTransfer?.types.includes("text/plain")) {
    e.preventDefault();
    e.dataTransfer!.dropEffect = "move";
  }
}

function onRootDragLeave() {
  dragOverCount--;
  if (dragOverCount <= 0) {
    dragOverCount = 0;
    rootDragOver.value = false;
  }
}

// ── Root context menu ──
const rootCtxVisible = ref(false);
const rootCtxX = ref(0);
const rootCtxY = ref(0);

const rootCtxItems = computed<MenuItem[]>(() => {
  const items: MenuItem[] = [];
  if (can("ServerCreate")) {
    items.push({ label: t("sidebar.newConnection"), action: "new-host" });
  }
  items.push({ label: t("sidebar.newGroup"), action: "new-group" });
  items.push({ label: t("sidebar.importConfig"), action: "import", divided: true });
  items.push({ label: t("sidebar.exportConfig"), action: "export" });
  if (teamStore.isJoined) {
    items.push({
      label: teamStore.syncing ? t("team.syncing") : t("team.sync"),
      action: "team-sync",
      divided: true,
    });
  }
  return items;
});

function onRootContextMenu(e: MouseEvent) {
  // Only show on the blank area, not on server/group items
  if ((e.target as HTMLElement).closest(".tm-tree-item")) return;
  e.preventDefault();
  rootCtxX.value = e.clientX;
  rootCtxY.value = e.clientY;
  rootCtxVisible.value = true;
}

async function onRootCtxSelect(action: string) {
  if (action === "new-host") {
    emit("new-host");
  } else if (action === "new-group") {
    try {
      const { value } = await ElMessageBox.prompt(
        t("sidebar.groupNameHint"),
        t("sidebar.newGroup"),
        {
          confirmButtonText: t("connection.save"),
          cancelButtonText: t("connection.cancel"),
          inputPattern: /\S+/,
          inputErrorMessage: t("sidebar.groupNameRequired"),
        },
      );
      await serverStore.createGroup({ name: value.trim() });
    } catch { /* cancelled */ }
  } else if (action === "import") {
    importConfig();
  } else if (action === "export") {
    exportConfig();
  } else if (action === "team-sync") {
    if (!teamStore.syncing) {
      try {
        const result = await teamStore.sync();
        if (result.conflicts.length === 0) {
          ElMessage.success(t("team.syncSuccess", { imported: result.imported, exported: result.exported }));
        }
      } catch (e) {
        const msg = String(e);
        // "team key not loaded" is handled centrally by teamStore (shows passphrase dialog)
        if (!msg.includes("team key not loaded")) {
          ElMessage.error(msg);
        }
      }
    }
  }
}

async function onRootDrop(e: DragEvent) {
  e.preventDefault();
  dragOverCount = 0;
  rootDragOver.value = false;
  const raw = e.dataTransfer?.getData("text/plain") ?? "";
  if (!raw.startsWith("termex-server:")) return;
  const serverId = raw.slice("termex-server:".length);

  const server = serverStore.servers.find((s) => s.id === serverId);
  if (!server || !server.groupId) return;

  const input: ServerInput = {
    name: server.name,
    host: server.host,
    port: server.port,
    username: server.username,
    authType: server.authType,
    keyPath: server.keyPath,
    groupId: null,
    startupCmd: server.startupCmd,
    tags: [...server.tags],
  };
  await serverStore.updateServer(serverId, input);
}
</script>

<template>
  <div
    ref="rootRef"
    class="text-xs flex-1"
    :class="{ 'bg-primary-500/5': rootDragOver }"
    @dragenter="onRootDragEnter"
    @dragover="onRootDragOver"
    @dragleave="onRootDragLeave"
    @drop="onRootDrop"
    @contextmenu="onRootContextMenu"
  >
    <!-- Filter tabs (only when joined a team) -->
    <div
      v-if="teamStore.isJoined"
      class="flex items-center gap-1 px-2 py-1"
      style="border-bottom: 1px solid var(--tm-border)"
    >
      <button
        v-for="f in (['all', 'private', 'team'] as const)"
        :key="f"
        class="px-2 py-0.5 rounded text-[10px] transition-colors"
        :class="
          serverFilter === f
            ? 'bg-primary-500/20 text-primary-400'
            : 'text-gray-500 hover:text-gray-300'
        "
        @click="serverFilter = f"
      >
        {{ t(`sidebar.filter_${f}`) }}
      </button>
    </div>

    <!-- Empty state -->
    <div v-if="!hasVisibleContent" class="px-4 py-8 text-center">
      <!-- Team tab: explain how team nodes work -->
      <template v-if="serverFilter === 'team' && teamStore.isJoined">
        <svg class="w-8 h-8 mx-auto mb-3 opacity-30" style="color: #60a5fa" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
          <circle cx="9" cy="7" r="4" />
          <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
          <path d="M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
        <p class="text-xs mb-1" style="color: var(--tm-text-secondary)">{{ t("sidebar.teamEmptyHint") }}</p>
        <p class="text-[10px] mb-4" style="color: var(--tm-text-muted)">{{ t("sidebar.teamEmptySync") }}</p>
        <button
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded text-xs transition-colors"
          style="background: rgba(96,165,250,0.12); color: #60a5fa"
          @click="serverFilter = 'private'"
        >
          {{ t("sidebar.goToPrivate") }}
        </button>
      </template>

      <!-- Normal / private tab: prompt to create -->
      <template v-else>
        <p class="mb-1 text-xs" style="color: var(--tm-text-muted)">{{ t("sidebar.servers") }}</p>
        <button
          class="mt-3 inline-flex items-center gap-1.5 px-3 py-1.5 rounded
                 bg-primary-500/10 text-primary-400 hover:bg-primary-500/20
                 hover:text-primary-300 text-xs transition-colors"
          @click="emit('new-host')"
        >
          <el-icon :size="12"><Plus /></el-icon>
          {{ t("sidebar.newConnection") }}
        </button>
      </template>
    </div>

    <template v-else-if="!teamStore.isJoined">
      <!-- Normal mode: no team, show original group tree -->
      <ServerGroup
        v-for="group in serverStore.groupTree"
        :key="group.id"
        :group="group"
        :servers="group.servers"
        @connect="handleConnect"
        @edit-server="(s) => emit('edit-server', s.id)"
        @new-host="emit('new-host')"
      />
      <ServerItem
        v-for="server in serverStore.filteredServers.filter(s => !s.groupId)"
        :key="server.id"
        :server="server"
        @connect="handleConnect"
        @edit="emit('edit-server', $event.id)"
      />
    </template>

    <template v-else>
      <!-- Team mode: split private / team sections -->

      <!-- ── Private section ── -->
      <template v-if="showPrivate && hasPrivate">
        <!-- Section header (only when showing both) -->
        <div
          v-if="serverFilter === 'all' && hasTeam"
          class="flex items-center gap-1.5 px-2 py-1 mt-0.5"
          style="color: var(--tm-text-muted)"
        >
          <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="11" width="18" height="11" rx="2" />
            <path d="M7 11V7a5 5 0 0 1 10 0v4" />
          </svg>
          <span class="text-[10px] font-medium">{{ t("sidebar.privateServers") }}</span>
        </div>

        <ServerGroup
          v-for="group in privateGroupTree"
          :key="group.id"
          :group="group"
          :servers="group.servers"
          @connect="handleConnect"
          @edit-server="(s) => emit('edit-server', s.id)"
          @new-host="emit('new-host')"
        />
        <ServerItem
          v-for="server in privateUngrouped"
          :key="server.id"
          :server="server"
          @connect="handleConnect"
          @edit="emit('edit-server', $event.id)"
        />
      </template>

      <!-- ── Divider ── -->
      <div
        v-if="serverFilter === 'all' && hasPrivate && hasTeam"
        class="mx-2 my-1"
        style="border-top: 1px solid var(--tm-border)"
      />

      <!-- ── Team section ── -->
      <template v-if="showTeam && hasTeam">
        <!-- Section header -->
        <div
          class="flex items-center gap-1.5 px-2 py-1"
          style="color: #60a5fa"
        >
          <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
          <span class="text-[10px] font-medium">{{ t("sidebar.teamServers") }}</span>
        </div>

        <ServerGroup
          v-for="group in teamGroupTree"
          :key="group.id + ':team'"
          :group="group"
          :servers="group.servers"
          @connect="handleConnect"
          @edit-server="(s) => emit('edit-server', s.id)"
          @new-host="emit('new-host')"
        />
        <ServerItem
          v-for="server in teamUngrouped"
          :key="server.id"
          :server="server"
          @connect="handleConnect"
          @edit="emit('edit-server', $event.id)"
        />
      </template>
    </template>

    <!-- Root context menu -->
    <ContextMenu
      v-if="rootCtxVisible"
      :items="rootCtxItems"
      :x="rootCtxX"
      :y="rootCtxY"
      @select="onRootCtxSelect"
      @close="rootCtxVisible = false"
    />
  </div>
</template>
