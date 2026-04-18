import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { tauriInvoke } from "@/utils/tauri";
import type { Proxy, ProxyInput } from "@/types/proxy";

export const useProxyStore = defineStore("proxy", () => {
  const proxies = ref<Proxy[]>([]);
  const loading = ref(false);

  /** A proxy belongs to the "team" view if it is shared (by me) or received from team. */
  const isTeamProxy = (p: Proxy) => !!p.shared || !!p.teamId;

  /** Proxies that are purely private (not shared, not received). */
  const privateProxies = computed(() => proxies.value.filter((p) => !isTeamProxy(p)));

  /** Proxies shared by me or received from team sync. */
  const teamProxies = computed(() => proxies.value.filter((p) => isTeamProxy(p)));

  async function fetchAll() {
    loading.value = true;
    try {
      proxies.value = await tauriInvoke<Proxy[]>("proxy_list");
    } finally {
      loading.value = false;
    }
  }

  async function create(input: ProxyInput): Promise<Proxy> {
    const proxy = await tauriInvoke<Proxy>("proxy_create", { input });
    proxies.value.push(proxy);
    return proxy;
  }

  async function update(id: string, input: ProxyInput): Promise<Proxy> {
    const proxy = await tauriInvoke<Proxy>("proxy_update", { id, input });
    const idx = proxies.value.findIndex((p) => p.id === id);
    if (idx !== -1) proxies.value[idx] = proxy;
    return proxy;
  }

  async function remove(id: string) {
    await tauriInvoke("proxy_delete", { id });
    proxies.value = proxies.value.filter((p) => p.id !== id);
  }

  async function getPassword(id: string): Promise<string> {
    return tauriInvoke<string>("proxy_get_password", { id });
  }

  async function setShared(id: string, shared: boolean): Promise<void> {
    await tauriInvoke("proxy_set_shared", { id, shared });
    const proxy = proxies.value.find((p) => p.id === id);
    if (proxy) proxy.shared = shared;
  }

  async function makeLocal(id: string): Promise<void> {
    await tauriInvoke("proxy_make_local", { id });
    const proxy = proxies.value.find((p) => p.id === id);
    if (proxy) { proxy.shared = false; proxy.teamId = undefined; proxy.sharedBy = undefined; }
  }

  return {
    proxies, loading, privateProxies, teamProxies,
    fetchAll, create, update, remove, getPassword, setShared, makeLocal,
  };
});
