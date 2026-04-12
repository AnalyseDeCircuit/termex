<script setup lang="ts">
import { computed, ref, reactive } from "vue";
import { useI18n } from "vue-i18n";
import { CopyDocument, Select } from "@element-plus/icons-vue";
import { renderMarkdown } from "@/composables/useMarkdown";
import type { ChatMessage } from "@/types/ai";

const { t } = useI18n();
const props = defineProps<{ message: ChatMessage }>();
const emit = defineEmits<{
  (e: "insert-command", cmd: string): void;
}>();

interface ContentBlock {
  type: "text" | "code";
  content: string;
  language?: string;
}

const parsedBlocks = computed<ContentBlock[]>(() => {
  if (props.message.role !== "assistant") return [];
  const blocks: ContentBlock[] = [];
  const regex = /```(\w*)\n([\s\S]*?)```/g;
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  const content = props.message.content;

  while ((match = regex.exec(content)) !== null) {
    if (match.index > lastIndex) {
      blocks.push({ type: "text", content: content.slice(lastIndex, match.index) });
    }
    blocks.push({ type: "code", content: match[2].trim(), language: match[1] || "bash" });
    lastIndex = match.index + match[0].length;
  }
  if (lastIndex < content.length) {
    blocks.push({ type: "text", content: content.slice(lastIndex) });
  }
  return blocks;
});

const contextExpanded = ref(false);

// Track copied state per key (block index or "all")
const copiedMap = reactive<Record<string, boolean>>({});

function copyText(text: string, key: string) {
  navigator.clipboard.writeText(text);
  copiedMap[key] = true;
  setTimeout(() => { copiedMap[key] = false; }, 1500);
}
</script>

<template>
  <!-- User message -->
  <div v-if="message.role === 'user'" class="flex justify-end">
    <div class="max-w-[85%] px-3 py-1.5 rounded-lg text-xs"
         style="background: var(--el-color-primary); color: white">
      {{ message.content }}
    </div>
  </div>

  <!-- Context marker -->
  <div v-else-if="message.role === 'context'" class="text-center">
    <button
      class="text-[10px] px-2 py-0.5 rounded transition-colors"
      style="color: var(--tm-text-muted); background: var(--tm-bg-hover)"
      @click="contextExpanded = !contextExpanded"
    >
      {{ message.content }} {{ contextExpanded ? "▼" : "▶" }}
    </button>
    <pre
      v-if="contextExpanded"
      class="text-[10px] text-left mt-1 p-2 rounded overflow-auto"
      style="background: var(--tm-bg-hover); color: var(--tm-text-muted); max-height: 200px"
    >{{ JSON.stringify(message.context, null, 2) }}</pre>
  </div>

  <!-- System message -->
  <div v-else-if="message.role === 'system'" class="text-center">
    <span class="text-[10px] px-2 py-0.5 rounded"
          style="color: var(--tm-text-muted); background: var(--tm-bg-hover)">
      {{ message.content }}
    </span>
  </div>

  <!-- Assistant message -->
  <div v-else class="max-w-[95%] rounded-lg px-2.5 py-2"
       style="background: var(--tm-ai-msg-assistant-bg, var(--tm-bg-hover)); border: 1px solid var(--tm-border)">
    <!-- Streaming indicator -->
    <div v-if="message.streaming" class="text-xs animate-pulse mb-1"
         style="color: var(--tm-text-muted)">
      {{ t("ai.thinking") }}
    </div>

    <!-- Parsed content blocks -->
    <template v-if="parsedBlocks.length > 0">
      <template v-for="(block, i) in parsedBlocks" :key="i">
        <!-- Text block: markdown rendered -->
        <div v-if="block.type === 'text'"
             class="text-xs leading-relaxed"
             style="color: var(--tm-text-primary)"
             v-html="renderMarkdown(block.content)" />
        <!-- Code block: interactive -->
        <div v-else class="my-1.5">
          <pre class="text-[11px] font-mono p-2 m-0 rounded overflow-x-auto"
               style="background: #0d1117; color: #e6edf3; border: 1px solid var(--tm-border)"><code>{{ block.content }}</code></pre>
          <div class="flex justify-end gap-1 mt-1">
            <button class="text-[10px] px-2 py-0.5 rounded transition-colors hover:bg-white/10"
                    style="color: var(--el-color-primary)"
                    @click="emit('insert-command', block.content)">
              {{ t("ai.insert") }}
            </button>
            <button
              class="p-1 rounded transition-colors hover:bg-white/10"
              :style="{ color: copiedMap[`block-${i}`] ? '#22c55e' : 'var(--tm-text-muted)' }"
              @click="copyText(block.content, `block-${i}`)"
            >
              <el-icon :size="12"><Select v-if="copiedMap[`block-${i}`]" /><CopyDocument v-else /></el-icon>
            </button>
          </div>
        </div>
      </template>
    </template>

    <!-- Fallback: markdown rendered (no code blocks found) -->
    <div v-else class="text-xs leading-relaxed"
         style="color: var(--tm-text-primary)"
         v-html="renderMarkdown(message.content)" />

    <!-- Copy entire message (only for pure text/markdown — code blocks have their own copy) -->
    <div v-if="!message.streaming && message.content && !parsedBlocks.some(b => b.type === 'code')" class="flex justify-end mt-1">
      <button
        class="p-1 rounded transition-colors hover:bg-white/10"
        :style="{ color: copiedMap['all'] ? '#22c55e' : 'var(--tm-text-muted)' }"
        @click="copyText(message.content, 'all')"
      >
        <el-icon :size="12"><Select v-if="copiedMap['all']" /><CopyDocument v-else /></el-icon>
      </button>
    </div>
  </div>
</template>
