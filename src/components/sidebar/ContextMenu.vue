<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from "vue";

export interface MenuItem {
  label: string;
  action: string;
  divided?: boolean;
  danger?: boolean;
  children?: MenuItem[];
}

defineProps<{
  items: MenuItem[];
  x: number;
  y: number;
}>();

const emit = defineEmits<{
  (e: "select", action: string): void;
  (e: "close"): void;
}>();

const menuRef = ref<HTMLDivElement | null>(null);
const openSub = ref<string | null>(null);

function handleClick(item: MenuItem) {
  if (item.children) return;
  emit("select", item.action);
  emit("close");
}

function onSubSelect(action: string) {
  emit("select", action);
  emit("close");
}

function onClickOutside(e: MouseEvent) {
  if (menuRef.value && !menuRef.value.contains(e.target as Node)) {
    emit("close");
  }
}

onMounted(() => {
  document.addEventListener("mousedown", onClickOutside, true);
});

onBeforeUnmount(() => {
  document.removeEventListener("mousedown", onClickOutside, true);
});
</script>

<template>
  <Teleport to="body">
    <div
      ref="menuRef"
      class="fixed z-[9999] min-w-[140px] py-1 rounded-md shadow-xl text-xs"
      style="background: var(--tm-bg-elevated); border: 1px solid var(--tm-border); color: var(--tm-text-primary)"
      :style="{ left: x + 'px', top: y + 'px' }"
    >
      <template v-for="item in items" :key="item.action">
        <div v-if="item.divided" class="my-1 border-t border-white/10" />

        <!-- Item with submenu -->
        <div
          v-if="item.children"
          class="relative"
          @mouseenter="openSub = item.action"
          @mouseleave="openSub = null"
        >
          <button
            class="w-full text-left px-3 py-1.5 hover:bg-white/10 transition-colors flex items-center justify-between"
          >
            <span>{{ item.label }}</span>
            <span class="ml-4 text-gray-500">&#x25B8;</span>
          </button>
          <!-- Submenu -->
          <div
            v-if="openSub === item.action"
            class="absolute left-full top-0 ml-0.5 min-w-[120px] py-1 rounded-md shadow-xl"
            style="background: var(--tm-bg-elevated); border: 1px solid var(--tm-border)"
          >
            <button
              v-for="child in item.children"
              :key="child.action"
              class="w-full text-left px-3 py-1.5 hover:bg-white/10 transition-colors whitespace-nowrap"
              :class="{ 'text-red-400 hover:text-red-300': child.danger }"
              @click="onSubSelect(child.action)"
            >
              {{ child.label }}
            </button>
          </div>
        </div>

        <!-- Normal item -->
        <button
          v-else
          class="w-full text-left px-3 py-1.5 hover:bg-white/10 transition-colors"
          :class="{ 'text-red-400 hover:text-red-300': item.danger }"
          @click="handleClick(item)"
        >
          {{ item.label }}
        </button>
      </template>
    </div>
  </Teleport>
</template>
