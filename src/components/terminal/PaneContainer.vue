<script setup lang="ts">
import { computed, ref, watch, nextTick } from "vue";
import type { PaneNode } from "@/types/paneLayout";
import { useSessionStore } from "@/stores/sessionStore";
import PaneDivider from "./PaneDivider.vue";
import PaneHeader from "./PaneHeader.vue";
import TabWorkspace from "./TabWorkspace.vue";

defineOptions({ name: "PaneContainer" });

const props = defineProps<{
  node: PaneNode;
  showHeaders: boolean;
}>();

const sessionStore = useSessionStore();
const workspaceRef = ref<InstanceType<typeof TabWorkspace>>();

const isLeaf = computed(() => props.node.type === "leaf");
const isSplit = computed(() => props.node.type === "split");

const isActivePane = computed(
  () => props.node.type === "leaf" && props.node.id === sessionStore.activePaneId,
);

const isBroadcasting = computed(() => {
  if (props.node.type !== "leaf") return false;
  const bc = sessionStore.currentBroadcast;
  return !!(bc?.enabled && bc.includedPaneIds.has(props.node.id));
});

// Split ratio → CSS styles
const firstChildStyle = computed(() => {
  if (props.node.type !== "split") return {};
  const pct = `${props.node.ratio * 100}%`;
  return props.node.direction === "horizontal"
    ? { height: pct, width: "100%" }
    : { width: pct, height: "100%" };
});

const secondChildStyle = computed(() => {
  if (props.node.type !== "split") return {};
  const pct = `${(1 - props.node.ratio) * 100}%`;
  return props.node.direction === "horizontal"
    ? { height: pct, width: "100%" }
    : { width: pct, height: "100%" };
});

function handlePaneClick() {
  if (props.node.type === "leaf") {
    sessionStore.setActivePane(props.node.id);
  }
}

// Auto-focus terminal when this pane becomes active
watch(isActivePane, async (active) => {
  if (active && props.node.type === "leaf") {
    await nextTick();
    workspaceRef.value?.focusTerminal();
  }
});

// Expose for parent to access the active pane's workspace
defineExpose({
  getWorkspace: () => workspaceRef.value,
});
</script>

<template>
  <!-- Leaf: render a single terminal pane -->
  <div
    v-if="isLeaf && node.type === 'leaf'"
    class="pane-leaf relative flex flex-col"
    :class="{
      'pane-active': isActivePane,
      'pane-broadcasting': isBroadcasting && !isActivePane,
    }"
    style="width: 100%; height: 100%"
    @mousedown="handlePaneClick"
  >
    <PaneHeader
      v-if="showHeaders"
      :pane-id="node.id"
      :title="node.title"
      :is-active="isActivePane"
      :is-broadcasting="isBroadcasting"
    />
    <div class="flex-1 min-h-0">
      <TabWorkspace
        ref="workspaceRef"
        :session-id="node.sessionId"
        :pane-id="node.id"
      />
    </div>

  </div>

  <!-- Split: render two children with a divider -->
  <div
    v-else-if="isSplit && node.type === 'split'"
    class="pane-split flex"
    :class="node.direction === 'horizontal' ? 'flex-col' : 'flex-row'"
    style="width: 100%; height: 100%"
  >
    <div :style="firstChildStyle" class="min-w-0 min-h-0 overflow-hidden">
      <PaneContainer :node="node.children[0]" :show-headers="showHeaders" />
    </div>

    <PaneDivider
      :split-id="node.id"
      :direction="node.direction"
      :ratio="node.ratio"
    />

    <div :style="secondChildStyle" class="min-w-0 min-h-0 overflow-hidden">
      <PaneContainer :node="node.children[1]" :show-headers="showHeaders" />
    </div>
  </div>
</template>
