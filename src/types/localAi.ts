export type ModelTier = "micro" | "small" | "medium" | "large";

export interface LocalModel {
  id: string;
  displayName: string;
  tier: ModelTier;
  sizeGb: number;
  minRamGb: number;
  contextLength: number;
  recommended: boolean;
  downloadUrl: string;
  mirrorUrl?: string;
  sha256: string;
  tags: string[];
}

export interface LocalModelsCatalog {
  schemaVersion: number;
  catalogVersion: string;
  models: LocalModel[];
}

export interface DownloadedModel {
  id: string;
  path: string;
  size: number;
  sha256?: string;
}

export interface EngineStatus {
  binaryReady: boolean;
  running: boolean;
  port?: number;
  loadedModel?: string;
}

export interface DownloadProgress {
  modelId: string;
  bytesDownloaded: number;
  totalBytes: number;
  percentComplete: number;
  estimatedTimeRemaining?: number;
}

export type ModelState =
  | "not_downloaded"
  | "downloading"
  | "downloaded"
  | "error"
  | "verifying";

export interface ModelStatus {
  id: string;
  state: ModelState;
  progress?: DownloadProgress;
  error?: string;
}
