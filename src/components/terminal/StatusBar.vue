<script setup lang="ts">
import { computed, ref, onMounted } from "vue";
import { useSessionStore } from "@/stores/sessionStore";
import { usePortForwardStore } from "@/stores/portForwardStore";
import { useTeamStore } from "@/stores/teamStore";
import { checkStatus as updateCheckStatus } from "@/utils/update";
import { tmuxStatusMap } from "@/composables/useTmux";
import { gitSyncStatusMap } from "@/composables/useGitSync";
import { tauriInvoke } from "@/utils/tauri";

const emit = defineEmits<{
  (e: "open-update"): void;
}>();

const sessionStore = useSessionStore();
const portForwardStore = usePortForwardStore();
const teamStore = useTeamStore();
const portable = ref(false);

onMounted(async () => {
  portable.value = await tauriInvoke<boolean>("is_portable").catch(() => false);
});

const activeForwardCount = computed(() => portForwardStore.activeForwards.size);

const statusText = computed(() => {
  const session = sessionStore.activeSession;
  if (!session) return "Ready";

  const cloudInfo = (() => {
    const meta = session.cloudMeta;
    if (!meta) return null;
    if (session.type === "kube-exec") {
      return `\u2388 ${meta.pod} \u00B7 ${meta.namespace} \u00B7 ${meta.context}`;
    }
    if (session.type === "ssm") {
      return `\u2B21 ${meta.instanceName ?? meta.instanceId} \u00B7 ${meta.region ?? ""}`;
    }
    if (session.type === "kube-logs") {
      return `\uD83D\uDCC4 ${meta.pod} [logs] \u00B7 ${meta.namespace}`;
    }
    return null;
  })();

  switch (session.status) {
    case "connecting":
      return "Connecting...";
    case "connected":
      return cloudInfo ?? `Connected | ${session.serverName}`;
    case "reconnecting":
      return "Reconnecting...";
    case "disconnected":
      return "Disconnected";
    case "error":
      return "Error";
    default:
      return "Ready";
  }
});

const tmuxStatus = computed(() => {
  const sid = sessionStore.activeSessionId;
  if (!sid) return null;
  return tmuxStatusMap.get(sid) ?? null;
});

const syncStatus = computed(() => {
  const sid = sessionStore.activeSessionId;
  if (!sid) return null;
  return gitSyncStatusMap.get(sid) ?? null;
});

const statusColor = computed(() => {
  const session = sessionStore.activeSession;
  if (!session) return "text-gray-500";
  switch (session.status) {
    case "connected":
      return "text-green-500";
    case "connecting":
    case "reconnecting":
      return "text-yellow-500";
    case "error":
      return "text-red-500";
    default:
      return "text-gray-500";
  }
});

</script>

<template>
  <div
    class="h-6 flex items-center px-3 text-xs shrink-0 select-none"
    style="background: var(--tm-statusbar-bg); border-top: 1px solid var(--tm-border)"
  >
    <span
      v-if="portable"
      class="text-[10px] px-1.5 py-0.5 rounded font-mono mr-2 text-amber-400"
      style="background: rgba(245, 158, 11, 0.15)"
    >USB</span>
    <span :class="statusColor">{{ statusText }}</span>

    <!-- Team sync indicator -->
    <span
      v-if="teamStore.syncing"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono text-blue-400 animate-pulse"
      style="background: rgba(96, 165, 250, 0.15)"
    >&#x21BB; {{ $t("team.syncing") }}</span>
    <span
      v-else-if="teamStore.syncStatusMessage"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono"
      :class="teamStore.syncStatusMessage.startsWith('\u2717') ? 'text-red-400' : 'text-green-400'"
      :style="teamStore.syncStatusMessage.startsWith('\u2717')
        ? 'background: rgba(248, 113, 113, 0.15)'
        : 'background: rgba(34, 197, 94, 0.15)'"
    >{{ teamStore.syncStatusMessage }}</span>

    <!-- tmux indicator -->
    <span
      v-if="tmuxStatus === 'active'"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono text-green-400"
      style="background: rgba(34, 197, 94, 0.15)"
    >tmux</span>
    <span
      v-else-if="tmuxStatus === 'detecting'"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono"
      style="color: var(--tm-text-muted)"
    >tmux</span>
    <span
      v-else-if="tmuxStatus === 'unavailable'"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono text-orange-400"
      style="background: rgba(251, 146, 60, 0.15)"
    >tmux &#x2717;</span>

    <button
      v-if="updateCheckStatus === 'available'"
      class="ml-2 text-[10px] text-primary-400 hover:text-primary-300 transition-colors cursor-pointer"
      @click="emit('open-update')"
    >
      &#x2B06; {{ $t("update.newVersion") }}
    </button>

    <!-- Forward count -->
    <span
      v-if="activeForwardCount > 0"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono"
      style="color: var(--tm-text-secondary)"
    >&#x21C4; {{ activeForwardCount }} forward{{ activeForwardCount > 1 ? 's' : '' }}</span>

    <!-- Git Sync indicator -->
    <span
      v-if="syncStatus === 'tunnel_active'"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono text-green-400"
      style="background: rgba(34, 197, 94, 0.15)"
    >&#x25CF; sync</span>
    <span
      v-else-if="syncStatus === 'pulling'"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono text-blue-400 animate-pulse"
    >&#x21BB; pull...</span>
    <span
      v-else-if="syncStatus === 'success'"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono text-green-400"
    >&#x2713; synced</span>
    <span
      v-else-if="syncStatus === 'error'"
      class="ml-2 text-[10px] px-1.5 py-0.5 rounded font-mono text-red-400"
    >&#x2717; sync</span>

    <span class="ml-auto" style="color: var(--tm-text-muted)">UTF-8</span>
  </div>
</template>
