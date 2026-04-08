<script setup lang="ts">
defineProps<{
  suggestions: string[]
  selectedIndex: number
  visible: boolean
  posX: number
  posY: number
}>()

const emit = defineEmits<{
  (e: 'select', index: number): void
  (e: 'dismiss'): void
}>()
</script>

<template>
  <Teleport to="body">
    <div
      v-if="visible && suggestions.length > 0"
      class="autocomplete-popup"
      :style="{ left: `${posX}px`, top: `${posY}px` }"
    >
      <div
        v-for="(cmd, i) in suggestions"
        :key="i"
        class="autocomplete-item"
        :class="{ 'is-selected': i === selectedIndex }"
        @click="emit('select', i)"
      >
        <span class="autocomplete-icon">AI</span>
        <span class="autocomplete-text">{{ cmd }}</span>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.autocomplete-popup {
  position: fixed;
  z-index: 9999;
  min-width: 300px;
  max-width: 500px;
  background: var(--tm-bg-surface, #1e1e2e);
  border: 1px solid var(--tm-border, #3b3b4f);
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  padding: 4px 0;
  font-family: var(--tm-font-mono, monospace);
  font-size: 13px;
}

.autocomplete-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 12px;
  cursor: pointer;
  color: var(--tm-text-primary, #cdd6f4);
}

.autocomplete-item:hover,
.autocomplete-item.is-selected {
  background: var(--tm-bg-hover, #313244);
}

.autocomplete-icon {
  font-size: 10px;
  padding: 1px 4px;
  border-radius: 3px;
  background: var(--el-color-primary, #6366f1);
  color: #fff;
  flex-shrink: 0;
  font-weight: 600;
}

.autocomplete-text {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
