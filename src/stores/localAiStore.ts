import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { tauriInvoke, tauriListen } from "@/utils/tauri";
import type {
  EngineStatus,
  DownloadedModel,
  ModelStatus,
  ModelState,
  LocalModelsCatalog,
} from "@/types/localAi";
import localModelsCatalog from "@/assets/local-models.json";

export const useLocalAiStore = defineStore("localAi", () => {
  const engineStatus = ref<EngineStatus | null>(null);
  const downloadedModels = ref<DownloadedModel[]>([]);
  const modelStates = ref<Map<string, ModelStatus>>(new Map());
  const unlisteners: Array<() => void> = [];

  const catalog = computed(() => localModelsCatalog as LocalModelsCatalog);

  const allModels = computed(() => catalog.value.models);

  const modelsByTier = computed(() => {
    return {
      micro: allModels.value.filter((m) => m.tier === "micro"),
      small: allModels.value.filter((m) => m.tier === "small"),
      medium: allModels.value.filter((m) => m.tier === "medium"),
      large: allModels.value.filter((m) => m.tier === "large"),
    };
  });

  /** Check the current engine status. */
  async function checkEngineStatus(): Promise<void> {
    try {
      engineStatus.value = await tauriInvoke<EngineStatus>(
        "local_ai_engine_status",
      );
    } catch (err) {
      console.error("Failed to check engine status:", err);
    }
  }

  /** Load all downloaded models from disk. */
  async function loadDownloaded(): Promise<void> {
    try {
      downloadedModels.value = await tauriInvoke<DownloadedModel[]>(
        "local_ai_list_downloaded",
      );

      // Update model states based on downloaded models
      for (const model of downloadedModels.value) {
        modelStates.value.set(model.id, {
          id: model.id,
          state: "downloaded",
        });
      }
    } catch (err) {
      console.error("Failed to load downloaded models:", err);
    }
  }

  /** Get the state of a model. */
  function getModelState(modelId: string): ModelState {
    const status = modelStates.value.get(modelId);
    if (status?.state === "downloading") {
      return "downloading";
    }
    if (status?.state === "error") {
      return "error";
    }
    if (downloadedModels.value.some((m) => m.id === modelId)) {
      return "downloaded";
    }
    return "not_downloaded";
  }

  /** Start the llama-server engine with a specific model. */
  async function startEngine(modelId: string): Promise<number> {
    const model = downloadedModels.value.find((m) => m.id === modelId);
    if (!model) {
      throw new Error(`Model ${modelId} not downloaded`);
    }

    try {
      const port = await tauriInvoke<number>("local_ai_start_engine", {
        modelPath: model.path,
      });
      await checkEngineStatus();
      return port;
    } catch (err) {
      console.error("Failed to start engine:", err);
      throw err;
    }
  }

  /** Stop the llama-server engine. */
  async function stopEngine(): Promise<void> {
    try {
      await tauriInvoke("local_ai_stop_engine");
      await checkEngineStatus();
    } catch (err) {
      console.error("Failed to stop engine:", err);
    }
  }

  /** Download a model from the given URL. */
  async function downloadModel(modelId: string): Promise<void> {
    const model = allModels.value.find((m) => m.id === modelId);
    if (!model) {
      throw new Error(`Model ${modelId} not found in catalog`);
    }

    console.log("[LocalAiStore] Download model:", modelId);
    console.log("[LocalAiStore] Model object:", model);
    console.log("[LocalAiStore] Download URL:", model.downloadUrl);
    console.log("[LocalAiStore] Mirror URL:", model.mirrorUrl);

    // Mark as downloading
    modelStates.value.set(modelId, {
      id: modelId,
      state: "downloading",
      progress: {
        modelId,
        bytesDownloaded: 0,
        totalBytes: Math.floor(model.sizeGb * 1024 * 1024 * 1024),
        percentComplete: 0,
      },
    });

    // Listen for progress events
    // Note: event names cannot contain dots, so we replace them with dashes
    const safeModelId = modelId.replace(/\./g, "-");
    const unlisten = await tauriListen<{
      model_id: string;
      bytes_downloaded: number;
      total_bytes: number;
      percent_complete: number;
    }>(
      `local-ai://download/${safeModelId}`,
      (progress) => {
        // Create a new object to trigger reactivity
        const newStatus = {
          id: modelId,
          state: "downloading" as const,
          progress: {
            modelId: progress.model_id,
            bytesDownloaded: progress.bytes_downloaded,
            totalBytes: progress.total_bytes,
            percentComplete: progress.percent_complete,
          },
        };
        modelStates.value.set(modelId, newStatus);
      },
    );
    unlisteners.push(unlisten);

    try {
      await tauriInvoke("local_ai_download_model", {
        modelId,
        url: model.downloadUrl,
        mirrorUrl: model.mirrorUrl,
        sha256: model.sha256,
      });

      // Mark as downloaded
      modelStates.value.set(modelId, {
        id: modelId,
        state: "downloaded",
      });

      // Reload downloaded models
      await loadDownloaded();
    } catch (err) {
      // Mark as error
      modelStates.value.set(modelId, {
        id: modelId,
        state: "error",
        error: String(err),
      });
      console.error(`Failed to download model ${modelId}:`, err);
      throw err;
    }
  }

  /** Cancel an ongoing download. */
  async function cancelDownload(modelId: string): Promise<void> {
    try {
      await tauriInvoke("local_ai_cancel_download", { modelId });
      modelStates.value.delete(modelId);
    } catch (err) {
      console.error(`Failed to cancel download for ${modelId}:`, err);
    }
  }

  /** Delete a downloaded model. */
  async function deleteModel(modelId: string): Promise<void> {
    try {
      await tauriInvoke("local_ai_delete_model", { modelId });
      downloadedModels.value = downloadedModels.value.filter(
        (m) => m.id !== modelId,
      );
      modelStates.value.delete(modelId);
    } catch (err) {
      console.error(`Failed to delete model ${modelId}:`, err);
      throw err;
    }
  }

  /** Cleanup: unlisten all event listeners. */
  function cleanup(): void {
    unlisteners.forEach((fn) => fn());
    unlisteners.length = 0;
  }

  return {
    engineStatus,
    downloadedModels,
    modelStates,
    catalog,
    allModels,
    modelsByTier,
    checkEngineStatus,
    loadDownloaded,
    getModelState,
    startEngine,
    stopEngine,
    downloadModel,
    cancelDownload,
    deleteModel,
    cleanup,
  };
});
