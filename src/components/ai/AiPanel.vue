<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { Delete, Setting } from "@element-plus/icons-vue";
import { useAiStore } from "@/stores/aiStore";
import { useSessionStore } from "@/stores/sessionStore";
import AiChatMessage from "./AiChatMessage.vue";
import AiMessage from "./AiMessage.vue";

const { t } = useI18n();
const aiStore = useAiStore();
const sessionStore = useSessionStore();
const emit = defineEmits<{
  (e: "insert-command", command: string): void;
  (e: "open-settings"): void;
}>();

const inputText = ref("");
const includeContext = ref(true);
const scrollRef = ref<HTMLElement>();
const sending = ref(false);

const hasProvider = computed(() => aiStore.providers.length > 0);
const activeSessionId = computed(() => sessionStore.activeSessionId);

// Multi-turn conversation for the active session
const conversation = computed(() => {
  if (!activeSessionId.value) return null;
  return aiStore.getConversation(activeSessionId.value);
});

const chatMessages = computed(() => conversation.value?.messages ?? []);
const hasChat = computed(() => chatMessages.value.length > 0);

// Legacy messages (from explain/nl2cmd — shown when no active session)
const legacyMessages = computed(() => aiStore.messages);

// Auto-scroll on new message
watch(
  () => chatMessages.value.length,
  async () => {
    await nextTick();
    if (scrollRef.value) {
      scrollRef.value.scrollTop = scrollRef.value.scrollHeight;
    }
  },
);

async function handleSend() {
  const text = inputText.value.trim();
  if (!text || sending.value) return;

  if (activeSessionId.value) {
    // Multi-turn chat mode
    inputText.value = "";
    sending.value = true;
    const context = includeContext.value
      ? (window as any).__termexCaptureContext?.(activeSessionId.value) ?? null
      : null;
    try {
      await aiStore.sendChat(activeSessionId.value, text, context);
    } finally {
      sending.value = false;
    }
  } else {
    // Legacy NL2Cmd mode (no active session)
    inputText.value = "";
    aiStore.messages.push({
      id: crypto.randomUUID(),
      role: "user",
      content: text,
      timestamp: new Date().toISOString(),
    });
  }
}

async function handleSummarize() {
  if (!activeSessionId.value) return;
  sending.value = true;
  const context = includeContext.value
    ? (window as any).__termexCaptureContext?.(activeSessionId.value) ?? null
    : null;
  // Read last 500 lines from terminal buffer (independent of context toggle)
  const bufferText = (window as any).__termexCaptureBuffer?.(activeSessionId.value, 500) ?? "";
  try {
    await aiStore.summarizeSession(activeSessionId.value, bufferText, context);
  } finally {
    sending.value = false;
  }
}

function handleClear() {
  if (activeSessionId.value) {
    aiStore.clearConversation(activeSessionId.value);
  } else {
    aiStore.clearMessages();
  }
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    handleSend();
  }
}

function handleInsert(command: string) {
  emit("insert-command", command);
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
      <div class="flex items-center gap-1">
        <!-- Summarize button -->
        <button
          v-if="activeSessionId"
          class="p-1 rounded transition-colors tm-icon-btn text-[10px]"
          :title="t('ai.summarize')"
          :disabled="sending"
          @click="handleSummarize"
        >
          {{ t("ai.summarize") }}
        </button>
        <button
          class="p-1 rounded transition-colors"
          :class="(hasChat || legacyMessages.length > 0) ? 'tm-icon-btn' : 'cursor-not-allowed opacity-30'"
          :title="t('ai.clear')"
          :disabled="!hasChat && legacyMessages.length === 0"
          @click="handleClear"
        >
          <el-icon :size="13"><Delete /></el-icon>
        </button>
      </div>
    </div>

    <!-- Content area -->
    <div ref="scrollRef" class="flex-1 overflow-y-auto p-3 space-y-3">
      <!-- No provider configured -->
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

      <!-- Multi-turn chat (active session) -->
      <template v-else-if="activeSessionId && hasChat">
        <AiChatMessage
          v-for="msg in chatMessages"
          :key="msg.id"
          :message="msg"
          @insert-command="handleInsert"
        />
      </template>

      <!-- Legacy messages (explain/nl2cmd, or no active session) -->
      <template v-else-if="legacyMessages.length > 0">
        <AiMessage
          v-for="msg in legacyMessages"
          :key="msg.id"
          :message="msg"
          @insert="handleInsert"
        />
      </template>

      <!-- Empty state -->
      <div
        v-else
        class="text-center text-xs py-8"
        style="color: var(--tm-text-muted)"
      >
        {{ t("ai.emptyHint") }}
      </div>
    </div>

    <!-- Input area -->
    <div v-if="hasProvider" class="shrink-0 px-2 py-2" style="border-top: 1px solid var(--tm-border)">
      <div v-if="activeSessionId" class="flex items-center gap-1 mb-1">
        <el-checkbox v-model="includeContext" size="small">
          <span class="text-[10px]">{{ t("ai.includeContext") }}</span>
        </el-checkbox>
      </div>
      <div class="flex gap-2">
        <el-input
          v-model="inputText"
          :placeholder="t('ai.inputPlaceholder')"
          size="small"
          :disabled="sending"
          @keydown="handleKeydown"
        />
        <el-button
          type="primary"
          size="small"
          :loading="sending"
          :disabled="!inputText.trim()"
          @click="handleSend"
        >
          {{ t("ai.send") }}
        </el-button>
      </div>
    </div>
  </div>
</template>
