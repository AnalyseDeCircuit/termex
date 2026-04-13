<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { useSessionStore } from "@/stores/sessionStore";

const { t } = useI18n();
const sessionStore = useSessionStore();
</script>

<template>
  <button
    v-if="sessionStore.paneCount > 1"
    class="px-2 h-full text-[10px] font-medium transition-all shrink-0"
    :class="sessionStore.currentBroadcast?.enabled
      ? 'text-orange-400'
      : 'hover:text-gray-300'"
    :style="{ color: sessionStore.currentBroadcast?.enabled ? '' : 'var(--tm-text-muted)' }"
    :title="sessionStore.currentBroadcast?.enabled
      ? t('terminal.broadcastHintOn')
      : t('terminal.broadcastHintOff')"
    @click="sessionStore.toggleBroadcast()"
  >
    {{ sessionStore.currentBroadcast?.enabled ? t('terminal.broadcastOn') : t('terminal.broadcastOff') }}
  </button>
</template>
