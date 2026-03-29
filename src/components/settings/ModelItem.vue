<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { ElButton, ElProgress } from "element-plus";
import { Download, Delete, Check, CircleCloseFilled } from "@element-plus/icons-vue";
import type { LocalModel, ModelState } from "@/types/localAi";

const { t } = useI18n();

interface Props {
  model: LocalModel;
  state: ModelState;
  progress: number;
}

interface Emits {
  (e: "download", model: LocalModel): void;
  (e: "cancel", modelId: string): void;
  (e: "delete", model: LocalModel): void;
  (e: "use-as-provider", model: LocalModel): void;
}

defineProps<Props>();
defineEmits<Emits>();
</script>

<template>
  <div class="model-item">
    <!-- Left: model info -->
    <div class="model-info">
      <div class="name-row">
        <h5>{{ model.displayName }}</h5>
        <span v-if="model.recommended" class="recommended-badge">
          ⭐ {{ t("localAi.recommended") }}
        </span>
      </div>
      <div class="meta-row">
        <span class="meta">{{ t("localAi.size") }}: {{ model.sizeGb }}GB</span>
        <span class="meta">{{ t("localAi.minRam") }}: {{ model.minRamGb }}GB</span>
        <span class="meta">{{ t("localAi.contextLength") }}: {{ model.contextLength }}</span>
      </div>
      <div v-if="state === 'downloading'" class="progress-row">
        <ElProgress :percentage="progress" />
      </div>
    </div>

    <!-- Right: actions -->
    <div class="model-actions">
      <!-- Not downloaded: show download button -->
      <template v-if="state === 'not_downloaded'">
        <ElButton
          type="primary"
          size="small"
          :icon="Download"
          @click="$emit('download', model)"
        >
          {{ t("localAi.download") }}
        </ElButton>
      </template>

      <!-- Downloaded: show use button and delete -->
      <template v-else-if="state === 'downloaded'">
        <ElButton
          type="success"
          size="small"
          :icon="Check"
          plain
        >
          {{ t("localAi.downloaded") }}
        </ElButton>
        <ElButton
          type="primary"
          size="small"
          @click="$emit('use-as-provider', model)"
        >
          {{ t("localAi.useAsProvider") }}
        </ElButton>
        <ElButton
          type="danger"
          size="small"
          :icon="Delete"
          @click="$emit('delete', model)"
        >
          {{ t("localAi.delete") }}
        </ElButton>
      </template>

      <!-- Downloading: show cancel button -->
      <template v-else-if="state === 'downloading'">
        <ElButton
          type="warning"
          size="small"
          @click="$emit('cancel', model.id)"
        >
          {{ t("localAi.cancel") }}
        </ElButton>
      </template>

      <!-- Error: show retry and delete -->
      <template v-else-if="state === 'error'">
        <ElButton
          type="danger"
          size="small"
          :icon="CircleCloseFilled"
        >
          {{ t("localAi.error") }}
        </ElButton>
        <ElButton
          type="primary"
          size="small"
          @click="$emit('download', model)"
        >
          {{ t("localAi.retry") }}
        </ElButton>
        <ElButton
          type="danger"
          size="small"
          :icon="Delete"
          @click="$emit('delete', model)"
        >
          {{ t("localAi.delete") }}
        </ElButton>
      </template>
    </div>
  </div>
</template>

<style scoped>
.model-item {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}

.model-info {
  flex: 1;
  min-width: 0;
}

.name-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
}

.model-info h5 {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
}

.recommended-badge {
  padding: 2px 8px;
  background-color: #fef3c7;
  border-radius: 3px;
  font-size: 11px;
  color: #92400e;
  white-space: nowrap;
}

.meta-row {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.meta {
  font-size: 12px;
  color: var(--tm-text-muted);
}

.progress-row {
  margin-top: 8px;
  width: 100%;
}

.model-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  justify-content: flex-end;
  white-space: nowrap;
}
</style>
