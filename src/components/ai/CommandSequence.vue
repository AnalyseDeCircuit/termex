<script setup lang="ts">
import { useI18n } from "vue-i18n";
import type { Playbook, OrchestratedStep } from "@/types/ai";

const { t } = useI18n();

defineProps<{
  playbook: Playbook;
}>();
const emit = defineEmits<{
  (e: "run-step", index: number): void;
  (e: "run-all"): void;
  (e: "close"): void;
}>();

function statusIcon(status: OrchestratedStep["status"]): string {
  switch (status) {
    case "success": return "\u2713";
    case "failed": return "\u2717";
    case "running": return "\u27F3";
    case "skipped": return "\u2013";
    default: return "\u25CB";
  }
}

function statusColor(status: OrchestratedStep["status"]): string {
  switch (status) {
    case "success": return "#22c55e";
    case "failed": return "#ef4444";
    case "running": return "#3b82f6";
    default: return "var(--tm-text-muted)";
  }
}
</script>

<template>
  <div class="rounded overflow-hidden" style="border: 1px solid var(--tm-border)">
    <!-- Header -->
    <div class="flex items-center gap-2 px-3 py-2" style="background: var(--tm-bg-hover)">
      <span class="text-xs font-medium flex-1" style="color: var(--tm-text-primary)">
        {{ playbook.goal }}
      </span>
      <button
        v-if="playbook.status === 'ready'"
        class="text-[10px] px-2 py-1 rounded transition-colors"
        style="color: white; background: var(--el-color-primary)"
        @click="emit('run-all')"
      >
        {{ t("ai.runAll") }}
      </button>
      <button class="text-xs" style="color: var(--tm-text-muted)" @click="emit('close')">
        &#x2715;
      </button>
    </div>

    <!-- Steps -->
    <div v-for="(step, i) in playbook.steps" :key="step.id"
         class="flex items-start gap-2 px-3 py-2 text-xs"
         style="border-top: 1px solid var(--tm-border)">
      <!-- Status icon -->
      <span class="shrink-0 w-4 text-center font-mono" :style="{ color: statusColor(step.status) }">
        {{ statusIcon(step.status) }}
      </span>

      <!-- Step info -->
      <div class="flex-1 min-w-0">
        <div style="color: var(--tm-text-secondary)">
          {{ step.stepNumber }}. {{ step.description }}
        </div>
        <pre class="text-[11px] font-mono mt-1 p-1.5 rounded overflow-x-auto"
             style="background: #0d1117; color: #e6edf3; margin: 0">{{ step.command }}</pre>
        <div v-if="step.validation" class="text-[10px] mt-1" style="color: var(--tm-text-muted)">
          {{ step.validation }}
        </div>
      </div>

      <!-- Run button -->
      <button
        v-if="step.status === 'pending'"
        class="text-[10px] px-2 py-1 rounded shrink-0 transition-colors"
        :style="{
          color: step.dangerous ? '#ef4444' : 'var(--el-color-primary)',
          background: step.dangerous ? 'rgba(239,68,68,0.1)' : 'rgba(var(--el-color-primary-rgb), 0.1)',
        }"
        @click="emit('run-step', i)"
      >
        {{ step.dangerous ? t("ai.confirmRun") : t("ai.run") }}
      </button>
      <span v-else-if="step.status === 'running'" class="animate-spin text-blue-400 shrink-0">
        &#x27F3;
      </span>
    </div>
  </div>
</template>
