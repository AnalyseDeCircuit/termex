<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { useCloudStore } from "@/stores/cloudStore";
import { useSessionStore } from "@/stores/sessionStore";
import { ElMessage } from "element-plus";

const { t } = useI18n();
const cloudStore = useCloudStore();
const sessionStore = useSessionStore();

async function toggleProfile(profile: string) {
  const key = `ssm-profile:${profile}`;
  cloudStore.toggleNode(key);
  if (cloudStore.isExpanded(key) && cloudStore.getSsmInstances(profile).length === 0) {
    try {
      await cloudStore.loadSsmInstances(profile);
    } catch (err) {
      const msg = String(err);
      if (msg.includes("ExpiredToken") || msg.includes("expired")) {
        ElMessage.error(t("cloud.ssmCredExpired"));
      } else {
        ElMessage.error(msg);
      }
    }
  }
}

function connectInstance(profile: string, instanceId: string, name: string) {
  sessionStore.openSsmSession({
    instanceId,
    instanceName: name,
    profile: profile !== "default" ? profile : undefined,
  });
}

function filteredInstances(profile: string) {
  const all = cloudStore.getSsmInstances(profile);
  const q = cloudStore.ssmFilter.trim().toLowerCase();
  if (!q) return all;
  return all.filter(
    (i) =>
      i.name.toLowerCase().includes(q) ||
      i.instanceId.toLowerCase().includes(q),
  );
}
</script>

<template>
  <div class="flex flex-col">
    <div
      class="flex items-center gap-1.5 px-2 py-1 text-xs font-medium cursor-pointer hover:bg-[var(--tm-bg-hover)]"
      style="color: var(--tm-text-secondary)"
      @click="cloudStore.toggleNode('ssm')"
    >
      <svg class="w-3 h-3 transition-transform" :class="{ 'rotate-90': cloudStore.isExpanded('ssm') }" viewBox="0 0 24 24" fill="currentColor">
        <path d="M10 6L16 12L10 18Z" />
      </svg>
      <span>{{ t("cloud.ssmTitle") }}</span>
    </div>

    <template v-if="cloudStore.isExpanded('ssm')">
      <div v-if="cloudStore.ssmProfiles.length === 0" class="px-6 py-2 text-xs" style="color: var(--tm-text-muted)">
        {{ t("cloud.ssmNoInstances") }}
      </div>

      <div v-for="profile in cloudStore.ssmProfiles" :key="profile">
        <div
          class="flex items-center gap-1.5 pl-5 pr-2 py-1 text-xs cursor-pointer hover:bg-[var(--tm-bg-hover)]"
          style="color: var(--tm-text-primary)"
          @click="toggleProfile(profile)"
        >
          <svg class="w-2.5 h-2.5 transition-transform shrink-0" :class="{ 'rotate-90': cloudStore.isExpanded(`ssm-profile:${profile}`) }" viewBox="0 0 24 24" fill="currentColor">
            <path d="M10 6L16 12L10 18Z" />
          </svg>
          <span class="truncate">{{ profile }}</span>
        </div>

        <template v-if="cloudStore.isExpanded(`ssm-profile:${profile}`)">
          <div v-if="cloudStore.isLoading(`ssm:${profile}/default`)" class="pl-10 py-1 text-xs animate-pulse" style="color: var(--tm-text-muted)">
            Loading...
          </div>

          <!-- Filter -->
          <div v-if="filteredInstances(profile).length > 10" class="pl-8 pr-2 py-1">
            <input
              v-model="cloudStore.ssmFilter"
              type="text"
              :placeholder="t('cloud.filterInstances')"
              class="w-full px-2 py-0.5 text-xs rounded border-0 outline-none"
              style="background: var(--tm-bg-secondary); color: var(--tm-text-primary)"
            />
          </div>

          <div
            v-for="inst in filteredInstances(profile)"
            :key="inst.instanceId"
            class="group flex items-center gap-1.5 pl-8 pr-2 py-1 text-xs cursor-pointer hover:bg-[var(--tm-bg-hover)]"
            style="color: var(--tm-text-primary)"
            @dblclick="inst.pingStatus === 'Online' && connectInstance(profile, inst.instanceId, inst.name)"
          >
            <span
              class="w-1.5 h-1.5 rounded-full shrink-0"
              :class="inst.pingStatus === 'Online' ? 'bg-green-500' : 'bg-gray-500'"
            />
            <span class="truncate flex-1">{{ inst.name }}</span>
            <span class="text-[10px] shrink-0 font-mono" style="color: var(--tm-text-muted)">
              {{ inst.instanceId.substring(0, 10) }}
            </span>

            <button
              v-if="inst.pingStatus === 'Online'"
              class="hidden group-hover:block p-0.5 rounded hover:bg-[var(--tm-bg-hover)]"
              :title="t('cloud.ssmConnect')"
              @click.stop="connectInstance(profile, inst.instanceId, inst.name)"
            >
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
            </button>
            <span
              v-else
              class="text-[10px]"
              style="color: var(--tm-text-muted)"
              :title="t('cloud.ssmAgentOffline')"
            >
              offline
            </span>
          </div>
        </template>
      </div>
    </template>
  </div>
</template>
