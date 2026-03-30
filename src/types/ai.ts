export type ProviderType =
  | "claude"
  | "openai"
  | "gemini"
  | "deepseek"
  | "ollama"
  | "grok"
  | "mistral"
  | "glm"
  | "minimax"
  | "doubao"
  | "local"
  | "custom";

export interface AiProvider {
  id: string;
  name: string;
  providerType: ProviderType;
  apiBaseUrl: string | null;
  model: string;
  maxTokens: number;
  temperature: number;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AiMessage {
  id: string;
  role: "user" | "assistant" | "system";
  content: string;
  timestamp: string;
}

export type DangerLevel = "warning" | "critical";

export interface DangerResult {
  isDangerous: boolean;
  level: DangerLevel | null;
  rule: string | null;
  description: string | null;
}

export interface ProviderInput {
  name: string;
  providerType: string;
  apiKey: string | null;
  apiBaseUrl: string | null;
  model: string;
  maxTokens: number;
  temperature: number;
  isDefault: boolean;
}

/** Default max tokens per provider. */
export const DEFAULT_MAX_TOKENS: Record<ProviderType, number> = {
  claude: 4096,
  openai: 4096,
  gemini: 8192,
  deepseek: 4096,
  ollama: 4096,
  grok: 4096,
  mistral: 4096,
  glm: 4096,
  minimax: 4096,
  doubao: 4096,
  local: 4096,
  custom: 4096,
};

/** Default models per provider type. */
export const DEFAULT_MODELS: Record<ProviderType, string[]> = {
  claude: [
    "claude-opus-4-6",
    "claude-sonnet-4-6",
    "claude-haiku-4-5-20251001",
  ],
  openai: [
    "gpt-5.2",
    "gpt-5.2-pro",
    "gpt-5",
    "gpt-5-mini",
    "o4-mini",
    "gpt-4o",
    "gpt-4o-mini",
    "o3",
    "o3-mini",
  ],
  gemini: [
    "gemini-3.1-pro-preview",
    "gemini-3-flash-preview",
    "gemini-2.5-flash",
    "gemini-2.5-flash-lite",
    "gemini-2.0-pro-exp",
  ],
  deepseek: ["deepseek-chat", "deepseek-reasoner"],
  ollama: [
    "llama3.3",
    "llama3.2",
    "qwen2.5",
    "qwen2.5-coder",
    "phi4",
    "gemma3",
    "deepseek-r1",
    "mistral",
    "codellama",
  ],
  grok: [
    "grok-4",
    "grok-4-1-fast-reasoning",
    "grok-4-1-fast-non-reasoning",
    "grok-code-fast-1",
    "grok-3",
  ],
  mistral: [
    "mistral-large-latest",
    "mistral-small-latest",
    "magistral-medium-latest",
    "magistral-small-latest",
    "codestral-latest",
    "devstral-latest",
  ],
  glm: [
    "glm-5",
    "glm-4-plus",
    "glm-4-air",
    "glm-4-flash",
    "glm-z1-flash",
    "glm-z1-air",
  ],
  minimax: ["MiniMax-M2.5", "MiniMax-M2.5-highspeed", "MiniMax-Text-01"],
  doubao: [],
  local: [],
  custom: [],
};

/** Default base URLs per provider type. */
export const PROVIDER_BASE_URLS: Record<ProviderType, string> = {
  claude: "https://api.anthropic.com",
  openai: "https://api.openai.com",
  gemini: "https://generativelanguage.googleapis.com",
  deepseek: "https://api.deepseek.com",
  ollama: "http://localhost:11434",
  grok: "https://api.x.ai",
  mistral: "https://api.mistral.ai",
  glm: "https://open.bigmodel.cn/api/paas/v4",
  minimax: "https://api.minimax.io/v1",
  doubao: "https://ark.cn-beijing.volces.com/api/v3",
  local: "http://localhost:15000",
  custom: "",
};

/** Display names for provider types. */
export const PROVIDER_NAMES: Record<ProviderType, string> = {
  claude: "Claude (Anthropic)",
  openai: "OpenAI",
  gemini: "Gemini (Google)",
  deepseek: "DeepSeek",
  ollama: "Ollama (Local)",
  grok: "Grok (xAI)",
  mistral: "Mistral",
  glm: "GLM (Zhipu)",
  minimax: "MiniMax",
  doubao: "Doubao (VolcEngine)",
  local: "Local AI (llama-server)",
  custom: "Custom (OpenAI Compatible)",
};
