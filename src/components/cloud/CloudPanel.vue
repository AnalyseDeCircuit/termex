<script setup lang="ts">
import { onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { useCloudStore } from "@/stores/cloudStore";
import CloudSetupGuide from "./CloudSetupGuide.vue";
import KubeContextTree from "./KubeContextTree.vue";
import SsmInstanceTree from "./SsmInstanceTree.vue";

const { t } = useI18n();
const cloudStore = useCloudStore();

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
});

async function refreshAll() {
  await cloudStore.detectTools();
  if (cloudStore.kubeAvailable) {
    await cloudStore.loadContexts().catch(() => {});
  }
  if (cloudStore.ssmAvailable) {
    await cloudStore.loadSsmProfiles().catch(() => {});
  }
}
</script>

<template>
  <div class="flex flex-col py-1">
    <!-- Neither K8s nor SSM available: show setup guide -->
    <CloudSetupGuide v-if="cloudStore.toolsLoaded && !cloudStore.kubeAvailable && !cloudStore.ssmAvailable" />

    <template v-else-if="cloudStore.toolsLoaded">
      <!-- Refresh button -->
      <div class="flex items-center justify-between px-2 pb-1">
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

      <KubeContextTree v-if="cloudStore.kubeAvailable" />
      <SsmInstanceTree v-if="cloudStore.ssmAvailable" />
    </template>

    <!-- Loading state -->
    <div v-else class="flex items-center justify-center py-8">
      <span class="text-xs animate-pulse" style="color: var(--tm-text-muted)">Loading...</span>
    </div>
  </div>
</template>
