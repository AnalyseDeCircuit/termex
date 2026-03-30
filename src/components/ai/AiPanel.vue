<script setup lang="ts">
import { computed, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { Delete, Setting } from "@element-plus/icons-vue";
import { useAiStore } from "@/stores/aiStore";
import AiInput from "./AiInput.vue";
import AiMessage from "./AiMessage.vue";

const { t } = useI18n();
const aiStore = useAiStore();
const emit = defineEmits<{
  (e: "insert-command", command: string): void;
  (e: "open-settings"): void;
}>();

const hasProvider = computed(() => aiStore.providers.length > 0);
const hasMessages = computed(() => aiStore.messages.length > 0);

function handleInsert(command: string) {
  emit("insert-command", command);
}

function clearMessages() {
  aiStore.messages = [];
}

onMounted(() => {
  aiStore.loadProviders();
});
</script>

<template>
  <div class="flex flex-col h-full" style="background: var(--tm-bg-surface)">
    <!-- Header -->
    <div
      class="flex items-center justify-between px-3 h-9 shrink-0"
      style="border-bottom: 1px solid var(--tm-border)"
    >
      <span class="text-xs font-medium" style="color: var(--tm-text-secondary)">
        {{ t("ai.panelTitle") }}
      </span>
      <button
        class="p-1 rounded transition-colors"
        :class="hasMessages ? 'tm-icon-btn' : 'cursor-not-allowed opacity-30'"
        :title="t('ai.clear')"
        :disabled="!hasMessages"
        @click="hasMessages && clearMessages()"
      >
        <el-icon :size="13"><Delete /></el-icon>
      </button>
    </div>

    <!-- Content area -->
    <div class="flex-1 overflow-y-auto p-3 space-y-3">
      <!-- No provider configured — guide -->
      <div
        v-if="!hasProvider"
        class="flex flex-col items-center justify-center h-full text-center gap-3"
      >
        <div class="text-2xl">&#x2728;</div>
        <div class="text-xs" style="color: var(--tm-text-muted)">
          {{ t("ai.noProviderHint") }}
        </div>
        <button
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded text-xs
                 bg-primary-500/10 text-primary-400 hover:bg-primary-500/20
                 hover:text-primary-300 transition-colors"
          @click="emit('open-settings')"
        >
          <el-icon :size="12"><Setting /></el-icon>
          {{ t("ai.goConfig") }}
        </button>
      </div>

      <!-- Has provider — show messages -->
      <template v-else>
        <AiMessage
          v-for="msg in aiStore.messages"
          :key="msg.id"
          :message="msg"
          @insert="handleInsert"
        />
        <div
          v-if="!hasMessages"
          class="text-center text-xs py-8"
          style="color: var(--tm-text-muted)"
        >
          {{ t("ai.emptyHint") }}
        </div>
      </template>
    </div>

    <!-- Input -->
    <AiInput :disabled="!hasProvider" />
  </div>
</template>
