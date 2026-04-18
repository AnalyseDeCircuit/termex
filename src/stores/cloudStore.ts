import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { tauriInvoke } from "@/utils/tauri";
import type {
  ToolStatus,
  KubeContext,
  PodInfo,
  SsmInstance,
  CloudFavorite,
  CloudFavoriteInput,
} from "@/types/cloud";

export const useCloudStore = defineStore("cloud", () => {
  // ── Tool detection ────────────────────────────────────────

  const tools = ref<ToolStatus[]>([]);
  const toolsLoaded = ref(false);

  const kubeAvailable = computed(
    () => tools.value.find((t) => t.name === "kubectl")?.available ?? false,
  );
  const ssmAvailable = computed(() => {
    const aws = tools.value.find((t) => t.name === "aws");
    const ssm = tools.value.find((t) => t.name === "session-manager-plugin");
    return (aws?.available ?? false) && (ssm?.available ?? false);
  });

  async function detectTools() {
    tools.value = await tauriInvoke<ToolStatus[]>("cloud_detect_tools");
    toolsLoaded.value = true;
  }

  // ── K8s ───────────────────────────────────────────────────

  const kubeContexts = ref<KubeContext[]>([]);
  const namespaces = ref<Record<string, string[]>>({});
  const pods = ref<Record<string, PodInfo[]>>({});
  const loading = ref<Record<string, boolean>>({});

  async function loadContexts() {
    loading.value["contexts"] = true;
    try {
      kubeContexts.value = await tauriInvoke<KubeContext[]>(
        "cloud_kube_list_contexts",
      );
    } finally {
      loading.value["contexts"] = false;
    }
  }

  async function loadNamespaces(context: string) {
    const key = `ns:${context}`;
    loading.value[key] = true;
    try {
      namespaces.value[context] = await tauriInvoke<string[]>(
        "cloud_kube_list_namespaces",
        { context },
      );
    } finally {
      loading.value[key] = false;
    }
  }

  async function loadPods(context: string, namespace: string) {
    const key = `${context}/${namespace}`;
    loading.value[key] = true;
    try {
      pods.value[key] = await tauriInvoke<PodInfo[]>(
        "cloud_kube_list_pods",
        { context, namespace },
      );
    } finally {
      loading.value[key] = false;
    }
  }

  function getPods(context: string, namespace: string): PodInfo[] {
    return pods.value[`${context}/${namespace}`] ?? [];
  }

  function isLoading(key: string): boolean {
    return loading.value[key] ?? false;
  }

  // ── AWS SSM ───────────────────────────────────────────────

  const ssmProfiles = ref<string[]>([]);
  const ssmInstances = ref<Record<string, SsmInstance[]>>({});

  async function loadSsmProfiles() {
    loading.value["ssm-profiles"] = true;
    try {
      ssmProfiles.value = await tauriInvoke<string[]>(
        "cloud_ssm_list_profiles",
      );
    } finally {
      loading.value["ssm-profiles"] = false;
    }
  }

  async function loadSsmInstances(profile?: string, region?: string) {
    const key = `ssm:${profile ?? "default"}/${region ?? "default"}`;
    loading.value[key] = true;
    try {
      ssmInstances.value[key] = await tauriInvoke<SsmInstance[]>(
        "cloud_ssm_list_instances",
        { profile: profile ?? null, region: region ?? null },
      );
    } finally {
      loading.value[key] = false;
    }
  }

  function getSsmInstances(profile?: string, region?: string): SsmInstance[] {
    const key = `ssm:${profile ?? "default"}/${region ?? "default"}`;
    return ssmInstances.value[key] ?? [];
  }

  // ── Cloud Favorites ───────────────────────────────────────

  const favorites = ref<CloudFavorite[]>([]);

  const isTeamFavorite = (f: CloudFavorite) => !!f.shared || !!f.teamId;
  const privateFavorites = computed(() => favorites.value.filter((f) => !isTeamFavorite(f)));
  const teamFavorites = computed(() => favorites.value.filter((f) => isTeamFavorite(f)));

  async function loadFavorites() {
    favorites.value = await tauriInvoke<CloudFavorite[]>("cloud_favorite_list");
  }

  /** Toggle share state for a context/profile. Creates favorite if not exists. */
  async function toggleFavoriteShare(
    resourceType: string,
    contextOrProfile: string,
    name: string,
    namespace?: string,
    region?: string,
  ) {
    const existing = favorites.value.find(
      (f) => f.resourceType === resourceType && f.contextOrProfile === contextOrProfile,
    );
    if (existing) {
      // Toggle shared
      await tauriInvoke("cloud_favorite_set_shared", { id: existing.id, shared: !existing.shared });
      if (!existing.shared) {
        // Was false → now true
        existing.shared = true;
      } else {
        // Was true → now false: remove if not team-received, else keep
        if (!existing.teamId) {
          // Private favorite that was shared — just unshare, keep as private favorite
          existing.shared = false;
        }
      }
    } else {
      const input: CloudFavoriteInput = { name, resourceType, contextOrProfile, namespace, region };
      const created = await tauriInvoke<CloudFavorite>("cloud_favorite_create", { input });
      await tauriInvoke("cloud_favorite_set_shared", { id: created.id, shared: true });
      created.shared = true;
      favorites.value.push(created);
    }
  }

  /** Returns true if the given context/profile has a shared favorite. */
  function isFavoriteShared(resourceType: string, contextOrProfile: string): boolean {
    return favorites.value.some(
      (f) => f.resourceType === resourceType && f.contextOrProfile === contextOrProfile && f.shared,
    );
  }

  /** Returns the favorite for a given context/profile (any state). */
  function getFavorite(resourceType: string, contextOrProfile: string): CloudFavorite | undefined {
    return favorites.value.find(
      (f) => f.resourceType === resourceType && f.contextOrProfile === contextOrProfile,
    );
  }

  async function makeLocalFavorite(id: string) {
    await tauriInvoke("cloud_favorite_make_local", { id });
    const fav = favorites.value.find((f) => f.id === id);
    if (fav) { fav.shared = false; fav.teamId = undefined; fav.sharedBy = undefined; }
  }

  async function deleteFavorite(id: string) {
    await tauriInvoke("cloud_favorite_delete", { id });
    favorites.value = favorites.value.filter((f) => f.id !== id);
  }

  // ── UI state ──────────────────────────────────────────────

  const expandedNodes = ref<Set<string>>(new Set());
  const podFilter = ref("");
  const ssmFilter = ref("");

  function toggleNode(key: string) {
    if (expandedNodes.value.has(key)) {
      expandedNodes.value.delete(key);
    } else {
      expandedNodes.value.add(key);
    }
  }

  function isExpanded(key: string): boolean {
    return expandedNodes.value.has(key);
  }

  return {
    tools,
    toolsLoaded,
    kubeAvailable,
    ssmAvailable,
    detectTools,
    kubeContexts,
    namespaces,
    pods,
    loading,
    loadContexts,
    loadNamespaces,
    loadPods,
    getPods,
    isLoading,
    ssmProfiles,
    ssmInstances,
    loadSsmProfiles,
    loadSsmInstances,
    getSsmInstances,
    expandedNodes,
    podFilter,
    ssmFilter,
    toggleNode,
    isExpanded,
    favorites,
    privateFavorites,
    teamFavorites,
    loadFavorites,
    toggleFavoriteShare,
    isFavoriteShared,
    getFavorite,
    makeLocalFavorite,
    deleteFavorite,
  };
});
