import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { tauriInvoke } from "@/utils/tauri";
import type {
  Server,
  ServerGroup,
  ServerInput,
  GroupInput,
  ReorderItem,
} from "@/types/server";

export const useServerStore = defineStore("server", () => {
  // ── State ──────────────────────────────────────────────────

  const servers = ref<Server[]>([]);
  const groups = ref<ServerGroup[]>([]);
  const loading = ref(false);
  const searchQuery = ref("");

  // ── Getters ────────────────────────────────────────────────

  /** Servers filtered by search query (name, host, tags). */
  const filteredServers = computed(() => {
    const q = searchQuery.value.toLowerCase().trim();
    if (!q) return servers.value;
    return servers.value.filter(
      (s) =>
        s.name.toLowerCase().includes(q) ||
        s.host.toLowerCase().includes(q) ||
        s.tags.some((t) => t.toLowerCase().includes(q)),
    );
  });

  /** Groups organized as a tree structure. */
  const groupTree = computed(() => {
    const rootGroups = groups.value.filter((g) => !g.parentId);
    return rootGroups.map((g) => ({
      ...g,
      children: groups.value.filter((c) => c.parentId === g.id),
      servers: servers.value.filter((s) => s.groupId === g.id),
    }));
  });

  /** Servers without a group. */
  const ungroupedServers = computed(() =>
    servers.value.filter((s) => !s.groupId),
  );

  /** Reference count for each bastion server (how many servers use it as proxy). */
  const proxyRefCounts = computed(() => {
    const counts = new Map<string, number>();
    for (const s of servers.value) {
      if (s.proxyId) {
        counts.set(s.proxyId, (counts.get(s.proxyId) ?? 0) + 1);
      }
    }
    return counts;
  });

  /** Quick lookup map from server ID to server object. */
  const serverById = computed(() => {
    return new Map(servers.value.map((s) => [s.id, s]));
  });

  // ── Actions ────────────────────────────────────────────────

  async function fetchAll() {
    loading.value = true;
    try {
      const [serverList, groupList] = await Promise.all([
        tauriInvoke<Server[]>("server_list"),
        tauriInvoke<ServerGroup[]>("group_list"),
      ]);
      servers.value = serverList;
      groups.value = groupList;
    } finally {
      loading.value = false;
    }
  }

  async function createServer(input: ServerInput): Promise<Server> {
    const server = await tauriInvoke<Server>("server_create", { input });
    servers.value.push(server);
    return server;
  }

  async function updateServer(id: string, input: ServerInput): Promise<Server> {
    const server = await tauriInvoke<Server>("server_update", { id, input });
    const idx = servers.value.findIndex((s) => s.id === id);
    if (idx !== -1) servers.value[idx] = server;
    return server;
  }

  async function deleteServer(id: string): Promise<void> {
    await tauriInvoke("server_delete", { id });
    servers.value = servers.value.filter((s) => s.id !== id);
  }

  async function touchServer(id: string): Promise<void> {
    await tauriInvoke("server_touch", { id });
    const server = servers.value.find((s) => s.id === id);
    if (server) server.lastConnected = new Date().toISOString();
  }

  async function setShared(id: string, shared: boolean): Promise<void> {
    await tauriInvoke("server_set_shared", { id, shared });
    const server = servers.value.find((s) => s.id === id);
    if (server) server.shared = shared;
  }

  async function reorderServers(orders: ReorderItem[]): Promise<void> {
    await tauriInvoke("server_reorder", { orders });
    for (const item of orders) {
      const s = servers.value.find((s) => s.id === item.id);
      if (s) s.sortOrder = item.sortOrder;
    }
  }

  async function createGroup(input: GroupInput): Promise<ServerGroup> {
    const group = await tauriInvoke<ServerGroup>("group_create", { input });
    groups.value.push(group);
    return group;
  }

  async function updateGroup(
    id: string,
    input: GroupInput,
  ): Promise<ServerGroup> {
    const group = await tauriInvoke<ServerGroup>("group_update", { id, input });
    const idx = groups.value.findIndex((g) => g.id === id);
    if (idx !== -1) groups.value[idx] = group;
    return group;
  }

  async function deleteGroup(id: string): Promise<void> {
    await tauriInvoke("group_delete", { id });
    groups.value = groups.value.filter((g) => g.id !== id);
    // Ungroup servers that belonged to this group
    servers.value.forEach((s) => {
      if (s.groupId === id) s.groupId = null;
    });
  }

  async function reorderGroups(orders: ReorderItem[]): Promise<void> {
    await tauriInvoke("group_reorder", { orders });
    for (const item of orders) {
      const g = groups.value.find((g) => g.id === item.id);
      if (g) g.sortOrder = item.sortOrder;
    }
  }

  return {
    // State
    servers,
    groups,
    loading,
    searchQuery,
    // Getters
    filteredServers,
    groupTree,
    ungroupedServers,
    proxyRefCounts,
    serverById,
    // Actions
    fetchAll,
    createServer,
    updateServer,
    deleteServer,
    touchServer,
    setShared,
    reorderServers,
    createGroup,
    updateGroup,
    deleteGroup,
    reorderGroups,
  };
});
