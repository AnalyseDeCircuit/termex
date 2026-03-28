<script setup lang="ts">
import { ref, computed, nextTick } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessageBox } from "element-plus";
import { Monitor } from "@element-plus/icons-vue";
import { useServerStore } from "@/stores/serverStore";
import type { Server, ServerInput } from "@/types/server";
import ContextMenu from "./ContextMenu.vue";
import type { MenuItem } from "./ContextMenu.vue";

const { t } = useI18n();
const serverStore = useServerStore();

const props = defineProps<{
  server: Server;
}>();

const emit = defineEmits<{
  (e: "connect", server: Server): void;
  (e: "edit", server: Server): void;
}>();

function toInput(overrides: Partial<ServerInput> = {}): ServerInput {
  return {
    name: props.server.name,
    host: props.server.host,
    port: props.server.port,
    username: props.server.username,
    authType: props.server.authType,
    keyPath: props.server.keyPath,
    groupId: props.server.groupId,
    startupCmd: props.server.startupCmd,
    tags: [...props.server.tags],
    ...overrides,
  };
}

// ── Inline rename ──
const renaming = ref(false);
const renameValue = ref("");
const renameInputRef = ref<HTMLInputElement | null>(null);

async function startRename() {
  renameValue.value = props.server.name;
  renaming.value = true;
  await nextTick();
  renameInputRef.value?.focus();
  renameInputRef.value?.select();
}

async function commitRename() {
  const trimmed = renameValue.value.trim();
  renaming.value = false;
  if (trimmed && trimmed !== props.server.name) {
    await serverStore.updateServer(props.server.id, toInput({ name: trimmed }));
  }
}

function cancelRename() {
  renaming.value = false;
}

// ── Tooltip ──
const tipVisible = ref(false);
const tipX = ref(0);
const tipY = ref(0);
let showTimer: ReturnType<typeof setTimeout> | null = null;

function onMouseEnter() {
  if (renaming.value) return;
  showTimer = setTimeout(() => { tipVisible.value = true; }, 500);
}

function onMouseMove(e: MouseEvent) {
  tipX.value = e.clientX + 12;
  tipY.value = e.clientY + 12;
}

function onMouseLeave() {
  if (showTimer) clearTimeout(showTimer);
  showTimer = null;
  tipVisible.value = false;
}

// ── Context menu ──
const ctxVisible = ref(false);
const ctxX = ref(0);
const ctxY = ref(0);

const ctxItems = computed<MenuItem[]>(() => {
  const items: MenuItem[] = [
    { label: t("context.connect"), action: "connect" },
    { label: t("context.edit"), action: "edit" },
    { label: t("context.rename"), action: "rename" },
  ];

  if (serverStore.groups.length > 0) {
    const groupChildren: MenuItem[] = serverStore.groups
      .filter((g) => g.id !== props.server.groupId)
      .map((g) => ({ label: g.name, action: `move:${g.id}` }));
    if (props.server.groupId) {
      groupChildren.push({ label: t("context.ungroup"), action: "ungroup", divided: true });
    }
    if (groupChildren.length > 0) {
      items.push({
        label: t("context.moveTo"),
        action: "_move",
        divided: true,
        children: groupChildren,
      });
    }
  }

  items.push({
    label: t("context.delete"),
    action: "delete",
    divided: true,
    danger: true,
  });

  return items;
});

function onContextMenu(e: MouseEvent) {
  if (renaming.value) return;
  e.preventDefault();
  tipVisible.value = false;
  ctxX.value = e.clientX;
  ctxY.value = e.clientY;
  ctxVisible.value = true;
}

async function onCtxSelect(action: string) {
  if (action === "connect") {
    emit("connect", props.server);
  } else if (action === "edit") {
    emit("edit", props.server);
  } else if (action === "rename") {
    startRename();
  } else if (action === "ungroup") {
    await serverStore.updateServer(props.server.id, toInput({ groupId: null }));
  } else if (action.startsWith("move:")) {
    const groupId = action.slice(5);
    await serverStore.updateServer(props.server.id, toInput({ groupId }));
  } else if (action === "delete") {
    try {
      await ElMessageBox.confirm(
        t("context.deleteConfirm", { name: props.server.name }),
        t("context.delete"),
        {
          confirmButtonText: t("connection.save"),
          cancelButtonText: t("connection.cancel"),
          type: "warning",
        },
      );
      await serverStore.deleteServer(props.server.id);
    } catch { /* cancelled */ }
  }
}

// ── Drag ──
const isDraggable = ref(false);
let dragTimer: ReturnType<typeof setTimeout> | null = null;

function onMouseDown() {
  if (renaming.value) return;
  // Delay enabling draggable to allow double-click to fire first
  dragTimer = setTimeout(() => {
    isDraggable.value = true;
  }, 150);
}

function onMouseUp() {
  if (dragTimer) { clearTimeout(dragTimer); dragTimer = null; }
  // Reset draggable after a short delay (after potential drop completes)
  setTimeout(() => { isDraggable.value = false; }, 50);
}

function onDragStart(e: DragEvent) {
  if (renaming.value) { e.preventDefault(); return; }
  tipVisible.value = false;
  e.dataTransfer!.effectAllowed = "move";
  e.dataTransfer!.setData("text/plain", `termex-server:${props.server.id}`);
}

function onDragEnd() {
  isDraggable.value = false;
}

function handleDblClick() {
  if (dragTimer) { clearTimeout(dragTimer); dragTimer = null; }
  isDraggable.value = false;
  emit("connect", props.server);
}
</script>

<template>
  <div
    class="tm-tree-item w-full flex items-center gap-1.5 px-2 py-1.5 transition-colors rounded-sm"
    :class="renaming ? '' : 'cursor-default'"
    :draggable="isDraggable"
    @dblclick="handleDblClick"
    @mousedown="onMouseDown"
    @mouseup="onMouseUp"
    @contextmenu="onContextMenu"
    @dragstart="onDragStart"
    @dragend="onDragEnd"
    @mouseenter="onMouseEnter"
    @mousemove="onMouseMove"
    @mouseleave="onMouseLeave"
  >
    <el-icon :size="12" class="shrink-0" style="color: var(--tm-text-muted)"><Monitor /></el-icon>

    <!-- Inline rename input -->
    <input
      v-if="renaming"
      ref="renameInputRef"
      v-model="renameValue"
      class="flex-1 min-w-0 text-xs px-1 py-0 rounded outline-none"
      style="background: var(--tm-input-bg); color: var(--tm-text-primary); border: 1px solid var(--tm-input-border)"
      @blur="commitRename"
      @keydown.enter="commitRename"
      @keydown.escape="cancelRename"
      @click.stop
      @dblclick.stop
    />
    <span v-else class="truncate">{{ server.name }}</span>
  </div>

  <!-- Cursor tooltip -->
  <Teleport to="body">
    <div
      v-show="tipVisible"
      class="fixed z-[9999] px-2 py-1 rounded text-xs shadow-lg pointer-events-none whitespace-nowrap"
      style="background: var(--tm-bg-elevated); color: var(--tm-text-primary); border: 1px solid var(--tm-border)"
      :style="{ left: tipX + 'px', top: tipY + 'px' }"
    >
      {{ server.host }}:{{ server.port }}
    </div>
  </Teleport>

  <!-- Context menu -->
  <ContextMenu
    v-if="ctxVisible"
    :items="ctxItems"
    :x="ctxX"
    :y="ctxY"
    @select="onCtxSelect"
    @close="ctxVisible = false"
  />
</template>
