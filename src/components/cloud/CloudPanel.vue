<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { useCloudStore } from "@/stores/cloudStore";
import { useTeamStore } from "@/stores/teamStore";
import CloudSetupGuide from "./CloudSetupGuide.vue";
import KubeContextTree from "./KubeContextTree.vue";
import SsmInstanceTree from "./SsmInstanceTree.vue";

const { t } = useI18n();
const cloudStore = useCloudStore();
const teamStore = useTeamStore();

const cloudFilter = ref<"all" | "private" | "team">("all");

const hasPrivateCloud = computed(() =>
  cloudStore.kubeAvailable || cloudStore.ssmAvailable,
);
const hasTeamFavorites = computed(() => cloudStore.teamFavorites.length > 0);

const showSplitView = computed(() =>
  teamStore.isJoined && cloudFilter.value === "all",
);

onMounted(async () => {
  if (!cloudStore.toolsLoaded) {
    await cloudStore.detectTools();
  }
  if (cloudStore.kubeAvailable && cloudStore.kubeContexts.length === 0) {
    await cloudStore.loadContexts().catch(() => {});
  }
  if (cloudStore.ssmAvailable && cloudStore.ssmProfiles.length === 0) {
    await cloudStore.loadSsmProfiles().catch(() => {});
  }
  await cloudStore.loadFavorites();
});

async function refreshAll() {
  await cloudStore.detectTools();
  if (cloudStore.kubeAvailable) {
    await cloudStore.loadContexts().catch(() => {});
  }
  if (cloudStore.ssmAvailable) {
    await cloudStore.loadSsmProfiles().catch(() => {});
  }
  await cloudStore.loadFavorites();
}
</script>

<template>
  <div class="flex flex-col h-full">

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
        :class="cloudFilter === f ? 'bg-primary-500/20 text-primary-400' : 'text-gray-500 hover:text-gray-300'"
        @click="cloudFilter = f"
      >
        {{ t(`sidebar.filter_${f}`) }}
      </button>
      <!-- Refresh -->
      <button
        class="ml-auto p-0.5 rounded hover:bg-[var(--tm-bg-hover)]"
        :title="t('cloud.refresh')"
        @click="refreshAll"
      >
        <svg class="w-3.5 h-3.5" style="color: var(--tm-text-muted)" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="23 4 23 10 17 10" /><polyline points="1 20 1 14 7 14" />
          <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15" />
        </svg>
      </button>
    </div>

    <!-- No tools: setup guide -->
    <template v-if="cloudStore.toolsLoaded && !cloudStore.kubeAvailable && !cloudStore.ssmAvailable">
      <CloudSetupGuide />
    </template>

    <!-- Loading -->
    <div v-else-if="!cloudStore.toolsLoaded" class="flex items-center justify-center py-8">
      <span class="text-xs animate-pulse" style="color: var(--tm-text-muted)">Loading...</span>
    </div>

    <template v-else>

      <!-- Header row with title + refresh (no team tabs) -->
      <div v-if="!teamStore.isJoined" class="flex items-center justify-between px-2 py-1 shrink-0">
        <span class="text-xs font-medium" style="color: var(--tm-text-secondary)">
          {{ t("cloud.title") }}
        </span>
        <button
          class="p-0.5 rounded hover:bg-[var(--tm-bg-hover)]"
          :title="t('cloud.refresh')"
          @click="refreshAll"
        >
          <svg class="w-3.5 h-3.5" style="color: var(--tm-text-muted)" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="23 4 23 10 17 10" /><polyline points="1 20 1 14 7 14" />
            <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15" />
          </svg>
        </button>
      </div>

      <!-- ── SPLIT VIEW: 全部 tab when team joined ── -->
      <div v-if="showSplitView" class="flex-1 overflow-y-auto">

        <!-- Private section: local CLI resources -->
        <template v-if="hasPrivateCloud">
          <KubeContextTree v-if="cloudStore.kubeAvailable" />
          <SsmInstanceTree v-if="cloudStore.ssmAvailable" />
        </template>

        <!-- Divider -->
        <div
          v-if="hasPrivateCloud && hasTeamFavorites"
          class="mx-2 my-1"
          style="border-top: 1px solid var(--tm-border)"
        />

        <!-- Team section header -->
        <div
          v-if="hasTeamFavorites"
          class="flex items-center gap-1.5 px-2 py-1"
          style="color: #60a5fa"
        >
          <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
          <span class="text-[10px] font-medium">{{ t("cloud.teamFavorites") }}</span>
        </div>

        <!-- Team favorites list -->
        <div
          v-for="fav in cloudStore.teamFavorites"
          :key="fav.id"
          class="group flex items-center gap-1.5 px-3 py-1.5 text-xs hover:bg-[var(--tm-bg-hover)]"
          style="color: var(--tm-text-primary)"
        >
          <!-- Resource type badge -->
          <span
            class="shrink-0 px-1 py-0 rounded text-[9px] font-medium"
            :style="fav.resourceType === 'kube'
              ? 'background: rgba(96,165,250,0.15); color: #60a5fa'
              : 'background: rgba(251,191,36,0.15); color: #fbbf24'"
          >
            {{ fav.resourceType === 'kube' ? 'K8S' : 'SSM' }}
          </span>
          <div class="flex-1 min-w-0">
            <div class="truncate font-medium">{{ fav.name }}</div>
            <div class="truncate text-[10px]" style="color: var(--tm-text-muted)">{{ fav.contextOrProfile }}</div>
          </div>
          <!-- sharedBy -->
          <span v-if="fav.sharedBy" class="shrink-0 text-[10px]" style="color: var(--tm-text-muted)">{{ fav.sharedBy }}</span>
          <!-- Make-local button (always visible) -->
          <el-tooltip
            v-if="fav.teamId"
            :content="t('team.receivedFrom', { name: fav.sharedBy || '?' })"
            :show-after="0"
          >
            <button
              class="shrink-0 p-0.5 rounded"
              style="color: var(--el-color-primary)"
              @click="cloudStore.makeLocalFavorite(fav.id)"
            >
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </button>
          </el-tooltip>
          <!-- Make-private button for shared-by-me favorites -->
          <el-tooltip
            v-else-if="fav.shared"
            :content="t('context.makePrivate')"
            :show-after="0"
          >
            <button
              class="shrink-0 p-0.5 rounded"
              style="color: var(--el-color-success)"
              @click="cloudStore.toggleFavoriteShare(fav.resourceType, fav.contextOrProfile, fav.name, fav.namespace, fav.region)"
            >
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </button>
          </el-tooltip>
        </div>

      </div>

      <!-- ── 私人 tab: only local CLI resources ── -->
      <div v-else-if="cloudFilter === 'private' || !teamStore.isJoined" class="flex-1 overflow-y-auto">
        <KubeContextTree v-if="cloudStore.kubeAvailable" />
        <SsmInstanceTree v-if="cloudStore.ssmAvailable" />
      </div>

      <!-- ── 团队 tab: only team favorites ── -->
      <div v-else-if="cloudFilter === 'team'" class="flex-1 overflow-y-auto py-1">
        <div
          v-if="cloudStore.teamFavorites.length === 0"
          class="flex flex-col items-center justify-center py-12 gap-2"
        >
          <span class="text-xs" style="color: var(--tm-text-muted)">{{ t("cloud.noTeamFavorites") }}</span>
        </div>
        <div
          v-for="fav in cloudStore.teamFavorites"
          :key="fav.id"
          class="group flex items-center gap-1.5 px-3 py-1.5 text-xs hover:bg-[var(--tm-bg-hover)]"
          style="color: var(--tm-text-primary)"
        >
          <span
            class="shrink-0 px-1 py-0 rounded text-[9px] font-medium"
            :style="fav.resourceType === 'kube'
              ? 'background: rgba(96,165,250,0.15); color: #60a5fa'
              : 'background: rgba(251,191,36,0.15); color: #fbbf24'"
          >
            {{ fav.resourceType === 'kube' ? 'K8S' : 'SSM' }}
          </span>
          <div class="flex-1 min-w-0">
            <div class="truncate font-medium">{{ fav.name }}</div>
            <div class="truncate text-[10px]" style="color: var(--tm-text-muted)">{{ fav.contextOrProfile }}</div>
          </div>
          <span v-if="fav.sharedBy" class="shrink-0 text-[10px]" style="color: var(--tm-text-muted)">{{ fav.sharedBy }}</span>
          <el-tooltip
            v-if="fav.teamId"
            :content="t('team.receivedFrom', { name: fav.sharedBy || '?' })"
            :show-after="0"
          >
            <button
              class="shrink-0 p-0.5 rounded"
              style="color: var(--el-color-primary)"
              @click="cloudStore.makeLocalFavorite(fav.id)"
            >
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </button>
          </el-tooltip>
          <el-tooltip
            v-else-if="fav.shared"
            :content="t('context.makePrivate')"
            :show-after="0"
          >
            <button
              class="shrink-0 p-0.5 rounded"
              style="color: var(--el-color-success)"
              @click="cloudStore.toggleFavoriteShare(fav.resourceType, fav.contextOrProfile, fav.name, fav.namespace, fav.region)"
            >
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </button>
          </el-tooltip>
        </div>
      </div>

    </template>
  </div>
</template>
