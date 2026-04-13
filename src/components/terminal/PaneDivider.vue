<script setup lang="ts">
import { ref } from "vue";
import { useSessionStore } from "@/stores/sessionStore";
import { MIN_SPLIT_RATIO, MAX_SPLIT_RATIO } from "@/types/paneLayout";
import * as paneTree from "@/utils/paneTree";

const props = defineProps<{
  splitId: string;
  direction: "horizontal" | "vertical";
  ratio: number;
}>();

const sessionStore = useSessionStore();
const isDragging = ref(false);

function onMouseDown(e: MouseEvent) {
  e.preventDefault();
  isDragging.value = true;

  const startPos = props.direction === "horizontal" ? e.clientY : e.clientX;
  const startRatio = props.ratio;

  // Get parent container dimensions
  const container = (e.target as HTMLElement).parentElement;
  if (!container) return;
  const containerSize =
    props.direction === "horizontal" ? container.clientHeight : container.clientWidth;

  function onMouseMove(ev: MouseEvent) {
    const currentPos = props.direction === "horizontal" ? ev.clientY : ev.clientX;
    const delta = (currentPos - startPos) / containerSize;
    const newRatio = Math.max(MIN_SPLIT_RATIO, Math.min(MAX_SPLIT_RATIO, startRatio + delta));

    // Update layout in store
    const tab = sessionStore.activeTab;
    if (!tab) return;
    const layout = sessionStore.paneLayouts.get(tab.tabKey);
    if (!layout) return;
    const updated = paneTree.updateRatio(layout, props.splitId, newRatio);
    sessionStore.paneLayouts.set(tab.tabKey, updated);
  }

  function onMouseUp() {
    isDragging.value = false;
    document.removeEventListener("mousemove", onMouseMove);
    document.removeEventListener("mouseup", onMouseUp);
    // Terminal resize handled by ResizeObserver in each TerminalView
  }

  document.addEventListener("mousemove", onMouseMove);
  document.addEventListener("mouseup", onMouseUp);
}
</script>

<template>
  <div
    class="pane-divider shrink-0"
    :class="[
      direction === 'horizontal'
        ? 'w-full h-1 cursor-row-resize'
        : 'h-full w-1 cursor-col-resize',
      isDragging ? 'is-dragging' : '',
    ]"
    style="z-index: 10"
    @mousedown="onMouseDown"
  />
</template>
