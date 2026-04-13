<script setup lang="ts">
import { computed } from "vue";
import { useSessionStore } from "@/stores/sessionStore";
import PaneContainer from "./PaneContainer.vue";

const props = defineProps<{
  tabKey: string;
}>();

const sessionStore = useSessionStore();

const layout = computed(() => sessionStore.paneLayouts.get(props.tabKey) ?? null);

// Show pane headers only when there are multiple panes
const showHeaders = computed(() => {
  if (!layout.value) return false;
  return layout.value.type === "split";
});

defineExpose({
  fit: () => {
    // Fit is handled by ResizeObserver in each TerminalView
  },
  dispose: () => {
    // Disposal handled by closeTabByKey
  },
  openSearch: () => {
    // TODO: forward to active pane's TerminalView
  },
  manualReconnect: () => {
    // TODO: forward to active pane's TerminalView
  },
  get search() {
    return undefined;
  },
});
</script>

<template>
  <PaneContainer
    v-if="layout"
    :node="layout"
    :show-headers="showHeaders"
  />
</template>
