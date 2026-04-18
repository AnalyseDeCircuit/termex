<script setup lang="ts">
import { ref, computed } from "vue";
import { useI18n } from "vue-i18n";
import { Edit, Delete, CaretRight, StarFilled, Star } from "@element-plus/icons-vue";
import { useTeamStore } from "@/stores/teamStore";
import ContextMenu from "@/components/sidebar/ContextMenu.vue";
import type { MenuItem } from "@/components/sidebar/ContextMenu.vue";
import type { Snippet } from "@/types/snippet";

const { t } = useI18n();
const teamStore = useTeamStore();

const props = withDefaults(defineProps<{
  snippet: Snippet;
  canExecute?: boolean;
}>(), {
  canExecute: true,
});

const emit = defineEmits<{
  (e: "execute", snippet: Snippet): void;
  (e: "edit", snippet: Snippet): void;
  (e: "delete", snippet: Snippet): void;
  (e: "toggle-favorite", snippet: Snippet): void;
  (e: "set-shared", snippet: Snippet, shared: boolean): void;
  (e: "make-local", snippet: Snippet): void;
}>();

const hovered = ref(false);

// ── Context menu ──
const ctxVisible = ref(false);
const ctxX = ref(0);
const ctxY = ref(0);

const isOwned = computed(() => !props.snippet.teamId);

const ctxItems = computed<MenuItem[]>(() => {
  const items: MenuItem[] = [];

  if (props.canExecute) {
    items.push({ label: t("snippet.execute"), action: "execute" });
  }

  if (isOwned.value) {
    items.push({ label: t("snippet.edit"), action: "edit" });
    items.push({ label: t("snippet.delete"), action: "delete", danger: true, divided: true });
  }

  // Team share toggle — always available for owned snippets when in a team
  if (teamStore.isJoined && isOwned.value) {
    if (props.snippet.shared) {
      items.push({ label: t("context.makePrivate"), action: "make-private", divided: true });
    } else {
      items.push({ label: t("context.shareWithTeam"), action: "share-team", divided: true });
    }
  }

  return items;
});

function onContextMenu(e: MouseEvent) {
  e.preventDefault();
  e.stopPropagation();
  ctxX.value = e.clientX;
  ctxY.value = e.clientY;
  ctxVisible.value = true;
}

function onCtxSelect(action: string) {
  if (action === "execute") emit("execute", props.snippet);
  else if (action === "edit") emit("edit", props.snippet);
  else if (action === "delete") emit("delete", props.snippet);
  else if (action === "share-team") emit("set-shared", props.snippet, true);
  else if (action === "make-private") emit("set-shared", props.snippet, false);
}
</script>

<template>
  <div
    class="group flex flex-col gap-0.5 px-2 py-1 mx-1 my-0.5 rounded transition-colors cursor-pointer"
    :style="{
      background: hovered ? 'var(--tm-bg-hover, rgba(255,255,255,0.04))' : 'transparent',
    }"
    @mouseenter="hovered = true"
    @mouseleave="hovered = false"
    @click="emit('execute', props.snippet)"
    @contextmenu="onContextMenu"
  >
    <!-- Top row: title + actions -->
    <div class="relative flex items-center gap-1.5 min-w-0">
      <!-- Favorite star -->
      <button
        class="shrink-0 rounded transition-colors flex items-center justify-center w-4 h-4"
        :title="props.snippet.isFavorite ? t('snippet.unfavorite') : t('snippet.favorite')"
        :style="{
          color: props.snippet.isFavorite
            ? 'var(--el-color-warning, #e6a23c)'
            : 'var(--tm-text-muted)',
        }"
        @click.stop="emit('toggle-favorite', props.snippet)"
      >
        <el-icon :size="12">
          <StarFilled v-if="props.snippet.isFavorite" />
          <Star v-else />
        </el-icon>
      </button>

      <!-- Title + tags inline -->
      <span class="flex-1 min-w-0 flex items-center gap-1 overflow-hidden">
        <span
          class="shrink-0 truncate text-xs font-medium"
          style="color: var(--tm-text-primary); max-width: 100%"
        >
          {{ props.snippet.title }}
        </span>
        <span
          v-for="tag in props.snippet.tags"
          :key="tag"
          class="shrink-0 px-1.5 py-0 rounded text-[10px]"
          style="
            background: var(--el-color-primary-light-9, rgba(64,158,255,0.08));
            color: var(--el-color-primary, #409eff);
          "
        >
          {{ tag }}
        </span>
      </span>

      <!-- Team share icon (right side of first row, same logic as ServerItem hover button) -->
      <el-tooltip
        v-if="teamStore.isJoined && !props.snippet.teamId"
        :content="props.snippet.shared ? t('context.makePrivate') : t('context.shareWithTeam')"
        :show-after="0"
      >
        <button
          class="shrink-0 p-0.5 rounded transition-all"
          :class="(hovered || props.snippet.shared) ? 'opacity-100' : 'opacity-0'"
          :style="{ color: props.snippet.shared ? 'var(--el-color-success)' : 'var(--tm-text-muted)', background: 'transparent' }"
          @click.stop="emit('set-shared', props.snippet, !props.snippet.shared)"
        >
          <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
        </button>
      </el-tooltip>
      <!-- Team received indicator (always visible, clicking converts to local) -->
      <el-tooltip
        v-else-if="props.snippet.teamId"
        :content="t('team.receivedFrom', { name: props.snippet.sharedBy || '?' })"
        :show-after="0"
      >
        <button
          class="shrink-0 p-0.5 rounded transition-all"
          style="color: var(--el-color-primary); background: transparent"
          @click.stop="emit('make-local', props.snippet)"
        >
          <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
        </button>
      </el-tooltip>

    </div>

    <!-- Second row: command preview + hover action buttons -->
    <div class="flex items-center gap-0.5 min-w-0">
      <!-- Command preview -->
      <span
        class="flex-1 min-w-0 truncate text-[11px] font-mono"
        style="color: var(--tm-text-muted)"
      >
        {{ props.snippet.command }}
      </span>

      <!-- Hover actions (right side of command row) -->
      <div class="shrink-0 flex items-center gap-0.5 ml-1" :class="hovered ? 'visible' : 'invisible'">
        <button
          v-if="canExecute"
          class="tm-icon-btn rounded transition-colors flex items-center justify-center w-5 h-5"
          :title="t('snippet.execute')"
          @click.stop="emit('execute', props.snippet)"
        >
          <el-icon :size="12"><CaretRight /></el-icon>
        </button>
        <button
          v-if="isOwned"
          class="tm-icon-btn rounded transition-colors flex items-center justify-center w-5 h-5"
          :title="t('snippet.edit')"
          @click.stop="emit('edit', props.snippet)"
        >
          <el-icon :size="12"><Edit /></el-icon>
        </button>
        <button
          v-if="isOwned"
          class="tm-icon-btn rounded transition-colors flex items-center justify-center w-5 h-5"
          :title="t('snippet.delete')"
          style="color: var(--el-color-danger, #f56c6c)"
          @click.stop="emit('delete', props.snippet)"
        >
          <el-icon :size="12"><Delete /></el-icon>
        </button>
      </div>
    </div>
  </div>

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
