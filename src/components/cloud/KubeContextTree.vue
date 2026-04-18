<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { useCloudStore } from "@/stores/cloudStore";
import { useSessionStore } from "@/stores/sessionStore";
import { useTeamStore } from "@/stores/teamStore";
import { ElMessage, ElMessageBox } from "element-plus";
import type { PodInfo } from "@/types/cloud";

const { t } = useI18n();
const cloudStore = useCloudStore();
const sessionStore = useSessionStore();
const teamStore = useTeamStore();

async function toggleContext(name: string) {
  const key = `ctx:${name}`;
  cloudStore.toggleNode(key);
  if (cloudStore.isExpanded(key) && !cloudStore.namespaces[name]) {
    try {
      await cloudStore.loadNamespaces(name);
    } catch (err) {
      ElMessage.error(String(err));
    }
  }
}

async function toggleNamespace(context: string, ns: string) {
  const key = `ns:${context}/${ns}`;
  cloudStore.toggleNode(key);
  if (cloudStore.isExpanded(key) && !cloudStore.pods[`${context}/${ns}`]) {
    try {
      await cloudStore.loadPods(context, ns);
    } catch (err) {
      ElMessage.error(String(err));
    }
  }
}

function podStatusColor(status: string): string {
  switch (status) {
    case "Running": return "bg-green-500";
    case "Succeeded": return "bg-blue-500";
    case "Pending": return "bg-yellow-500";
    case "Failed": return "bg-red-500";
    default: return "bg-gray-500";
  }
}

function filteredPods(context: string, ns: string): PodInfo[] {
  const all = cloudStore.getPods(context, ns);
  const q = cloudStore.podFilter.trim().toLowerCase();
  if (!q) return all;
  return all.filter((p) => p.name.toLowerCase().includes(q));
}

async function connectPod(context: string, pod: PodInfo) {
  if (pod.status !== "Running") {
    ElMessage.warning(`Pod ${pod.name} is ${pod.status}`);
    return;
  }

  let container: string | undefined;
  let shell: string | undefined;

  if (pod.containers.length > 1) {
    const names = pod.containers
      .filter((c) => c.state === "running")
      .map((c) => c.name);
    if (names.length === 0) {
      ElMessage.warning("No running containers");
      return;
    }
    try {
      const { value } = await ElMessageBox.prompt(
        t("cloud.kubeSelectContainer"),
        { inputValue: names[0], inputPattern: new RegExp(`^(${names.join("|")})$`) },
      );
      container = value;
    } catch {
      return;
    }
  }

  sessionStore.openKubeExec({
    context,
    namespace: pod.namespace,
    pod: pod.name,
    container,
    shell,
  });
}

async function viewLogs(context: string, pod: PodInfo) {
  let container: string | undefined;
  if (pod.containers.length > 1) {
    const names = pod.containers.map((c) => c.name);
    try {
      const { value } = await ElMessageBox.prompt(
        t("cloud.kubeSelectContainer"),
        { inputValue: names[0], inputPattern: new RegExp(`^(${names.join("|")})$`) },
      );
      container = value;
    } catch {
      return;
    }
  }

  sessionStore.openKubeLogs({
    context,
    namespace: pod.namespace,
    pod: pod.name,
    container,
    tailLines: 100,
  });
}

async function refreshPods(context: string, ns: string) {
  try {
    await cloudStore.loadPods(context, ns);
  } catch (err) {
    ElMessage.error(String(err));
  }
}
</script>

<template>
  <div class="flex flex-col">
    <!-- Section header -->
    <div
      class="flex items-center gap-1.5 px-2 py-1 text-xs font-medium cursor-pointer hover:bg-[var(--tm-bg-hover)]"
      style="color: var(--tm-text-secondary)"
      @click="cloudStore.toggleNode('kube')"
    >
      <svg class="w-3 h-3 transition-transform" :class="{ 'rotate-90': cloudStore.isExpanded('kube') }" viewBox="0 0 24 24" fill="currentColor">
        <path d="M10 6L16 12L10 18Z" />
      </svg>
      <span>{{ t("cloud.kubeClusters") }}</span>
    </div>

    <template v-if="cloudStore.isExpanded('kube')">
      <div v-if="cloudStore.kubeContexts.length === 0" class="px-6 py-2 text-xs" style="color: var(--tm-text-muted)">
        {{ t("cloud.kubeNoContexts") }}
      </div>

      <div v-for="ctx in cloudStore.kubeContexts" :key="ctx.name">
        <!-- Context node -->
        <div
          class="group flex items-center gap-1.5 pl-5 pr-2 py-1 text-xs cursor-pointer hover:bg-[var(--tm-bg-hover)]"
          style="color: var(--tm-text-primary)"
          @click="toggleContext(ctx.name)"
        >
          <svg class="w-2.5 h-2.5 transition-transform shrink-0" :class="{ 'rotate-90': cloudStore.isExpanded(`ctx:${ctx.name}`) }" viewBox="0 0 24 24" fill="currentColor">
            <path d="M10 6L16 12L10 18Z" />
          </svg>
          <span class="truncate flex-1">{{ ctx.name }}</span>
          <span v-if="ctx.isCurrent" class="text-green-500 text-[10px] shrink-0">*</span>
          <!-- Team share toggle -->
          <el-tooltip
            v-if="teamStore.isJoined"
            :content="cloudStore.isFavoriteShared('kube', ctx.name) ? t('context.makePrivate') : t('context.shareWithTeam')"
            :show-after="0"
          >
            <button
              class="shrink-0 p-0.5 rounded transition-all"
              :class="cloudStore.isFavoriteShared('kube', ctx.name) ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'"
              :style="{ color: cloudStore.isFavoriteShared('kube', ctx.name) ? 'var(--el-color-success)' : 'var(--tm-text-muted)', background: 'transparent' }"
              @click.stop="cloudStore.toggleFavoriteShare('kube', ctx.name, ctx.name, ctx.namespace)"
            >
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </button>
          </el-tooltip>
        </div>

        <!-- Namespaces -->
        <template v-if="cloudStore.isExpanded(`ctx:${ctx.name}`)">
          <div v-if="cloudStore.isLoading(`ns:${ctx.name}`)" class="pl-10 py-1 text-xs animate-pulse" style="color: var(--tm-text-muted)">
            Loading...
          </div>
          <div v-for="ns in (cloudStore.namespaces[ctx.name] ?? [])" :key="ns">
            <div
              class="flex items-center gap-1.5 pl-8 pr-2 py-1 text-xs cursor-pointer hover:bg-[var(--tm-bg-hover)]"
              style="color: var(--tm-text-primary)"
              @click="toggleNamespace(ctx.name, ns)"
            >
              <svg class="w-2.5 h-2.5 transition-transform shrink-0" :class="{ 'rotate-90': cloudStore.isExpanded(`ns:${ctx.name}/${ns}`) }" viewBox="0 0 24 24" fill="currentColor">
                <path d="M10 6L16 12L10 18Z" />
              </svg>
              <span class="truncate">{{ ns }}</span>
            </div>

            <!-- Pods -->
            <template v-if="cloudStore.isExpanded(`ns:${ctx.name}/${ns}`)">
              <div v-if="cloudStore.isLoading(`${ctx.name}/${ns}`)" class="pl-12 py-1 text-xs animate-pulse" style="color: var(--tm-text-muted)">
                Loading...
              </div>
              <template v-else>
                <!-- Filter input for large pod lists -->
                <div v-if="cloudStore.getPods(ctx.name, ns).length > 20" class="pl-11 pr-2 py-1">
                  <input
                    v-model="cloudStore.podFilter"
                    type="text"
                    :placeholder="t('cloud.filterPods')"
                    class="w-full px-2 py-0.5 text-xs rounded border-0 outline-none"
                    style="background: var(--tm-bg-secondary); color: var(--tm-text-primary)"
                  />
                </div>

                <div v-if="filteredPods(ctx.name, ns).length === 0" class="pl-12 py-1 text-xs" style="color: var(--tm-text-muted)">
                  {{ t("cloud.kubeNoPods") }}
                </div>

                <div
                  v-for="pod in filteredPods(ctx.name, ns)"
                  :key="pod.name"
                  class="group flex items-center gap-1.5 pl-11 pr-2 py-1 text-xs cursor-pointer hover:bg-[var(--tm-bg-hover)]"
                  style="color: var(--tm-text-primary)"
                  @dblclick="connectPod(ctx.name, pod)"
                >
                  <span class="w-1.5 h-1.5 rounded-full shrink-0" :class="podStatusColor(pod.status)" />
                  <span class="truncate flex-1">{{ pod.name }}</span>
                  <span class="text-[10px] shrink-0" style="color: var(--tm-text-muted)">{{ pod.ready }}</span>

                  <!-- Action buttons (hover) -->
                  <div class="hidden group-hover:flex items-center gap-0.5 ml-1">
                    <button
                      v-if="pod.status === 'Running'"
                      class="p-0.5 rounded hover:bg-[var(--tm-bg-hover)]"
                      :title="t('cloud.kubeConnect')"
                      @click.stop="connectPod(ctx.name, pod)"
                    >
                      <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
                    </button>
                    <button
                      class="p-0.5 rounded hover:bg-[var(--tm-bg-hover)]"
                      :title="t('cloud.kubeViewLogs')"
                      @click.stop="viewLogs(ctx.name, pod)"
                    >
                      <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
                    </button>
                  </div>
                </div>

                <!-- Refresh button -->
                <div class="pl-11 pr-2 py-0.5">
                  <button
                    class="text-[10px] hover:underline"
                    style="color: var(--tm-text-muted)"
                    @click="refreshPods(ctx.name, ns)"
                  >
                    {{ t("cloud.refresh") }}
                  </button>
                </div>
              </template>
            </template>
          </div>
        </template>
      </div>
    </template>
  </div>
</template>
