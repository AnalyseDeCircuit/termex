<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { useSessionStore } from "@/stores/sessionStore";

const { t } = useI18n();

const props = defineProps<{
  paneId: string;
  title: string;
  isActive: boolean;
  isBroadcasting: boolean;
}>();

const sessionStore = useSessionStore();

function splitVertical() {
  sessionStore.setActivePane(props.paneId);
  sessionStore.splitActivePane("vertical");
}

function splitHorizontal() {
  sessionStore.setActivePane(props.paneId);
  sessionStore.splitActivePane("horizontal");
}

function handleClosePane() {
  sessionStore.closePane(props.paneId);
}

function handleToggleBroadcast() {
  sessionStore.togglePaneBroadcast(props.paneId);
}
</script>

<template>
  <div
    class="pane-header flex items-center justify-between px-2 h-6 shrink-0 text-xs select-none"
    :class="{ 'is-active': isActive }"
  >
    <span class="truncate">{{ title }}</span>
    <div class="flex items-center gap-0.5">
      <button
        class="px-1 py-0.5 rounded text-[10px] transition-colors"
        :class="isBroadcasting ? 'text-orange-400' : ''"
        :style="{ color: isBroadcasting ? '' : 'var(--tm-text-muted)' }"
        :title="t('terminal.broadcastToggle')"
        @click.stop="handleToggleBroadcast"
      >
        BC
      </button>
      <button
        class="px-1 py-0.5 rounded transition-colors"
        style="color: var(--tm-text-muted)"
        :title="t('terminal.splitVertical')"
        @click.stop="splitVertical"
      >
        <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1.2">
          <rect x="0.5" y="0.5" width="9" height="9" />
          <line x1="5" y1="0.5" x2="5" y2="9.5" />
        </svg>
      </button>
      <button
        class="px-1 py-0.5 rounded transition-colors"
        style="color: var(--tm-text-muted)"
        :title="t('terminal.splitHorizontal')"
        @click.stop="splitHorizontal"
      >
        <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1.2">
          <rect x="0.5" y="0.5" width="9" height="9" />
          <line x1="0.5" y1="5" x2="9.5" y2="5" />
        </svg>
      </button>
      <button
        class="px-1 py-0.5 rounded transition-colors"
        style="color: var(--tm-text-muted)"
        :title="t('terminal.closePane')"
        @click.stop="handleClosePane"
      >
        <svg width="8" height="8" viewBox="0 0 10 10" stroke="currentColor" stroke-width="1.5">
          <line x1="1" y1="1" x2="9" y2="9" />
          <line x1="9" y1="1" x2="1" y2="9" />
        </svg>
      </button>
    </div>
  </div>
</template>
