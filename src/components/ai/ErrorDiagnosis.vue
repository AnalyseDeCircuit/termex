<script setup lang="ts">
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { renderMarkdown } from "@/composables/useMarkdown";
import type { DetectedError } from "@/composables/useErrorDetection";

const { t } = useI18n();

const props = defineProps<{
  error: DetectedError;
  diagnosis: string;
  loading: boolean;
}>();
const emit = defineEmits<{
  (e: "insert-command", cmd: string): void;
  (e: "dismiss"): void;
}>();

const fixCommands = computed(() => {
  const regex = /```(?:bash|sh)?\n([\s\S]*?)```/g;
  const cmds: string[] = [];
  let match: RegExpExecArray | null;
  while ((match = regex.exec(props.diagnosis)) !== null) {
    cmds.push(match[1].trim());
  }
  return cmds;
});
</script>

<template>
  <div class="rounded overflow-hidden" style="border: 1px solid var(--tm-border)">
    <!-- Header -->
    <div class="flex items-center gap-2 px-3 py-2"
         :style="{
           background: error.severity === 'critical' ? 'rgba(239,68,68,0.1)' : 'rgba(234,179,8,0.1)',
           borderBottom: '1px solid var(--tm-border)',
         }">
      <span class="text-xs font-medium"
            :style="{ color: error.severity === 'critical' ? '#ef4444' : '#eab308' }">
        {{ t("ai.errorDetected") }}
      </span>
      <div class="flex-1" />
      <button class="text-xs" style="color: var(--tm-text-muted)" @click="emit('dismiss')">
        {{ t("ai.dismiss") }}
      </button>
    </div>

    <!-- Error info -->
    <div class="px-3 py-2 space-y-1">
      <div class="text-[11px]" style="color: var(--tm-text-secondary)">
        <strong>{{ t("ai.command") }}:</strong> <code>{{ error.command }}</code>
      </div>
      <pre class="text-[10px] font-mono p-1.5 rounded overflow-x-auto max-h-20"
           style="background: var(--tm-bg-hover); color: var(--tm-text-muted); margin: 0">{{ error.errorOutput.slice(0, 500) }}</pre>
    </div>

    <!-- AI Analysis -->
    <div class="px-3 py-2" style="border-top: 1px solid var(--tm-border)">
      <div v-if="loading" class="text-xs animate-pulse" style="color: var(--tm-text-muted)">
        {{ t("ai.analyzing") }}
      </div>
      <div v-else class="text-xs" style="color: var(--tm-text-primary)" v-html="renderMarkdown(diagnosis)" />

      <!-- Quick fix buttons -->
      <div v-if="fixCommands.length > 0" class="flex flex-wrap gap-1 mt-2">
        <button
          v-for="(cmd, i) in fixCommands"
          :key="i"
          class="text-[10px] px-2 py-1 rounded transition-colors"
          style="color: var(--el-color-primary); background: rgba(var(--el-color-primary-rgb), 0.1)"
          @click="emit('insert-command', cmd)"
        >
          {{ t("ai.runFix") }}: {{ cmd.slice(0, 40) }}{{ cmd.length > 40 ? "..." : "" }}
        </button>
      </div>
    </div>
  </div>
</template>
