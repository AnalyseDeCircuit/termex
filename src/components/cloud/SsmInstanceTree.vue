<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { useCloudStore } from "@/stores/cloudStore";
import { useSessionStore } from "@/stores/sessionStore";
import { useTeamStore } from "@/stores/teamStore";
import { ElMessage } from "element-plus";

const { t } = useI18n();
const cloudStore = useCloudStore();
const sessionStore = useSessionStore();
const teamStore = useTeamStore();

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
          class="group flex items-center gap-1.5 pl-5 pr-2 py-1 text-xs cursor-pointer hover:bg-[var(--tm-bg-hover)]"
          style="color: var(--tm-text-primary)"
          @click="toggleProfile(profile)"
        >
          <svg class="w-2.5 h-2.5 transition-transform shrink-0" :class="{ 'rotate-90': cloudStore.isExpanded(`ssm-profile:${profile}`) }" viewBox="0 0 24 24" fill="currentColor">
            <path d="M10 6L16 12L10 18Z" />
          </svg>
          <span class="truncate flex-1">{{ profile }}</span>
          <!-- Team share toggle -->
          <el-tooltip
            v-if="teamStore.isJoined"
            :content="cloudStore.isFavoriteShared('ssm', profile) ? t('context.makePrivate') : t('context.shareWithTeam')"
            :show-after="0"
          >
            <button
              class="shrink-0 p-0.5 rounded transition-all"
              :class="cloudStore.isFavoriteShared('ssm', profile) ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'"
              :style="{ color: cloudStore.isFavoriteShared('ssm', profile) ? 'var(--el-color-success)' : 'var(--tm-text-muted)', background: 'transparent' }"
              @click.stop="cloudStore.toggleFavoriteShare('ssm', profile, profile)"
            >
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </button>
          </el-tooltip>
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
