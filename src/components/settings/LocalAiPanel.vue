<script setup lang="ts">
import { onMounted, onBeforeUnmount } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage, ElMessageBox } from "element-plus";
import { tauriInvoke } from "@/utils/tauri";
import { useLocalAiStore } from "@/stores/localAiStore";
import { useAiStore } from "@/stores/aiStore";
import ModelItem from "./ModelItem.vue";
import type { LocalModel } from "@/types/localAi";

const { t } = useI18n();
const localAiStore = useLocalAiStore();
const aiStore = useAiStore();

/** Initialize store on component mount. */
onMounted(async () => {
  await localAiStore.checkEngineStatus();
  await localAiStore.loadDownloaded();
});

/** Cleanup listeners on unmount. */
onBeforeUnmount(() => {
  localAiStore.cleanup();
});

/** Handle download button click. */
async function handleDownload(model: LocalModel): Promise<void> {
  try {
    // Check disk space before downloading
    await tauriInvoke("local_ai_check_disk_space", {
      modelSizeGb: model.sizeGb,
    });

    await localAiStore.downloadModel(model.id);
    ElMessage.success(t("localAi.downloadStarted", { name: model.displayName }));
  } catch (err) {
    ElMessage.error(
      t("localAi.downloadFailed", { error: String(err) }),
    );
  }
}

/** Handle cancel button click. */
async function handleCancel(modelId: string): Promise<void> {
  try {
    await localAiStore.cancelDownload(modelId);
    ElMessage.info(t("localAi.downloadCancelled"));
  } catch (err) {
    ElMessage.error(String(err));
  }
}

/** Handle delete button click with confirmation. */
async function handleDelete(model: LocalModel): Promise<void> {
  try {
    await ElMessageBox.confirm(
      t("localAi.deleteConfirm", { name: model.displayName }),
      t("localAi.warning"),
      { confirmButtonText: "OK", cancelButtonText: "Cancel", type: "warning" },
    );
    await localAiStore.deleteModel(model.id);
    ElMessage.success(t("localAi.deleted"));
  } catch (err) {
    if (String(err) !== "cancel") {
      ElMessage.error(String(err));
    }
  }
}

/** Handle "use as AI provider" button click. */
async function handleUseAsProvider(model: LocalModel): Promise<void> {
  try {
    // Create a new local provider
    await aiStore.addProvider({
      name: `Local: ${model.displayName}`,
      providerType: "local",
      apiKey: null,
      apiBaseUrl: null,
      model: model.id,
      maxTokens: 4096,
      temperature: 0.7,
      isDefault: false,
    });
    ElMessage.success(t("localAi.addedAsProvider"));
  } catch (err) {
    ElMessage.error(String(err));
  }
}

/** Get percentage for progress bar. */
function getProgress(modelId: string): number {
  const status = localAiStore.modelStates.get(modelId);
  return status?.progress?.percentComplete ?? 0;
}
</script>

<template>
  <div class="local-ai-panel">
    <!-- Header -->
    <div class="panel-header">
      <h3>{{ t("localAi.title") }}</h3>
      <div class="engine-status">
        <span v-if="localAiStore.engineStatus?.running" class="status-badge running">
          {{ t("localAi.engineRunning") }}
        </span>
        <span v-else class="status-badge stopped">
          {{ t("localAi.engineStopped") }}
        </span>
      </div>
    </div>

    <!-- Models by tier -->
    <div class="models-container">
      <!-- Micro tier -->
      <div class="tier-section">
        <h4>{{ t("localAi.microTier") }}</h4>
        <p class="tier-desc">{{ t("localAi.microDesc") }}</p>
        <div class="models-list">
          <div
            v-for="model in localAiStore.modelsByTier.micro"
            :key="model.id"
            class="model-card"
          >
            <ModelItem
              :model="model"
              :state="localAiStore.getModelState(model.id)"
              :progress="getProgress(model.id)"
              @download="handleDownload"
              @cancel="handleCancel"
              @delete="handleDelete"
              @use-as-provider="handleUseAsProvider"
            />
          </div>
        </div>
      </div>

      <!-- Small tier -->
      <div class="tier-section">
        <h4>{{ t("localAi.smallTier") }}</h4>
        <p class="tier-desc">{{ t("localAi.smallDesc") }}</p>
        <div class="models-list">
          <div
            v-for="model in localAiStore.modelsByTier.small"
            :key="model.id"
            class="model-card"
          >
            <ModelItem
              :model="model"
              :state="localAiStore.getModelState(model.id)"
              :progress="getProgress(model.id)"
              @download="handleDownload"
              @cancel="handleCancel"
              @delete="handleDelete"
              @use-as-provider="handleUseAsProvider"
            />
          </div>
        </div>
      </div>

      <!-- Medium tier -->
      <div class="tier-section">
        <h4>{{ t("localAi.mediumTier") }}</h4>
        <p class="tier-desc">{{ t("localAi.mediumDesc") }}</p>
        <div class="models-list">
          <div
            v-for="model in localAiStore.modelsByTier.medium"
            :key="model.id"
            class="model-card"
          >
            <ModelItem
              :model="model"
              :state="localAiStore.getModelState(model.id)"
              :progress="getProgress(model.id)"
              @download="handleDownload"
              @cancel="handleCancel"
              @delete="handleDelete"
              @use-as-provider="handleUseAsProvider"
            />
          </div>
        </div>
      </div>

      <!-- Large tier -->
      <div class="tier-section">
        <h4>{{ t("localAi.largeTier") }}</h4>
        <p class="tier-desc">{{ t("localAi.largeDesc") }}</p>
        <div class="models-list">
          <div
            v-for="model in localAiStore.modelsByTier.large"
            :key="model.id"
            class="model-card"
          >
            <ModelItem
              :model="model"
              :state="localAiStore.getModelState(model.id)"
              :progress="getProgress(model.id)"
              @download="handleDownload"
              @cancel="handleCancel"
              @delete="handleDelete"
              @use-as-provider="handleUseAsProvider"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.local-ai-panel {
  padding: 16px;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.panel-header h3 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
}

.engine-status {
  display: flex;
  gap: 8px;
}

.status-badge {
  padding: 4px 12px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
}

.status-badge.running {
  background-color: #f0f9ff;
  color: #0369a1;
}

.status-badge.stopped {
  background-color: #fef2f2;
  color: #991b1b;
}

.models-container {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.tier-section {
  border: 1px solid var(--tm-border);
  border-radius: 8px;
  padding: 16px;
  background-color: var(--tm-bg-secondary);
}

.tier-section h4 {
  margin: 0 0 8px 0;
  font-size: 14px;
  font-weight: 600;
}

.tier-desc {
  margin: 0 0 12px 0;
  font-size: 12px;
  color: var(--tm-text-muted);
}

.models-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.model-card {
  padding: 12px;
  border: 1px solid var(--tm-border);
  border-radius: 6px;
  background-color: var(--tm-bg-base);
}
</style>
