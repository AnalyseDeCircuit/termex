import '../state/conversation_provider.dart';

/// Static metadata for each AI provider.
class ProviderMeta {
  final AiProvider provider;
  final String label;
  final String description;
  final List<String> models;
  final bool requiresApiKey;
  final bool requiresBaseUrl;

  const ProviderMeta({
    required this.provider,
    required this.label,
    required this.description,
    required this.models,
    required this.requiresApiKey,
    this.requiresBaseUrl = false,
  });
}

/// Registry of all supported AI providers and their model lists.
///
/// v0.77.0 restored the full vendor roster from the Tauri build:
/// - Native wire formats: Claude / OpenAI / Gemini / Ollama / Local AI
/// - OpenAI-compatible: DeepSeek / Grok / Mistral / GLM / MiniMax / Doubao
///   (these share the OpenAI chat-completions schema; the Rust bridge
///   routes them through a per-vendor default base URL.)
const List<ProviderMeta> kProviderRegistry = [
  ProviderMeta(
    provider: AiProvider.claude,
    label: 'Claude',
    description: 'Anthropic Claude — best for code and reasoning',
    models: [
      'claude-opus-4-7',
      'claude-sonnet-4-6',
      'claude-haiku-4-5-20251001',
    ],
    requiresApiKey: true,
  ),
  ProviderMeta(
    provider: AiProvider.openAi,
    label: 'OpenAI',
    description: 'OpenAI GPT — versatile general-purpose models',
    models: [
      'gpt-4o',
      'gpt-4o-mini',
      'gpt-4-turbo',
      'gpt-3.5-turbo',
    ],
    requiresApiKey: true,
  ),
  ProviderMeta(
    provider: AiProvider.gemini,
    label: 'Gemini',
    description: 'Google Gemini — multimodal flagship',
    models: [
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-2.0-flash-exp',
    ],
    requiresApiKey: true,
  ),
  ProviderMeta(
    provider: AiProvider.ollama,
    label: 'Ollama',
    description: 'Local models via Ollama (must be running)',
    models: [
      'llama3',
      'llama3:70b',
      'mistral',
      'codellama',
      'qwen2',
    ],
    requiresApiKey: false,
    requiresBaseUrl: true,
  ),
  ProviderMeta(
    provider: AiProvider.localLlama,
    label: 'Local AI',
    description: 'Built-in llama-server managed by Termex',
    models: [
      'llama3-8b-q4',
      'phi3-mini-q4',
      'qwen2-7b-q4',
    ],
    requiresApiKey: false,
  ),
  ProviderMeta(
    provider: AiProvider.deepSeek,
    label: 'DeepSeek',
    description: 'DeepSeek — strong code + math, OpenAI-compatible',
    models: [
      'deepseek-chat',
      'deepseek-reasoner',
      'deepseek-coder',
    ],
    requiresApiKey: true,
  ),
  ProviderMeta(
    provider: AiProvider.grok,
    label: 'Grok',
    description: 'xAI Grok — real-time knowledge, OpenAI-compatible',
    models: [
      'grok-beta',
      'grok-2-latest',
      'grok-2-mini',
    ],
    requiresApiKey: true,
  ),
  ProviderMeta(
    provider: AiProvider.mistral,
    label: 'Mistral',
    description: 'Mistral AI — European frontier, OpenAI-compatible',
    models: [
      'mistral-large-latest',
      'mistral-medium-latest',
      'mistral-small-latest',
      'codestral-latest',
    ],
    requiresApiKey: true,
  ),
  ProviderMeta(
    provider: AiProvider.glm,
    label: 'GLM (智谱)',
    description: '智谱 GLM — Chinese flagship, OpenAI-compatible',
    models: [
      'glm-4',
      'glm-4-plus',
      'glm-4-air',
      'glm-4-flash',
    ],
    requiresApiKey: true,
  ),
  ProviderMeta(
    provider: AiProvider.minimax,
    label: 'MiniMax',
    description: 'MiniMax — long-context Chinese model',
    models: [
      'abab6.5-chat',
      'abab6.5s-chat',
      'abab5.5-chat',
    ],
    requiresApiKey: true,
  ),
  ProviderMeta(
    provider: AiProvider.doubao,
    label: '豆包 (Doubao)',
    description: '字节豆包 — 火山方舟，OpenAI-compatible',
    models: [
      'doubao-pro-32k',
      'doubao-pro-128k',
      'doubao-lite-32k',
    ],
    requiresApiKey: true,
  ),
  // v0.79.63: 阿里云百炼 / 通义千问 (DashScope OpenAI-compat endpoint).
  // Default base URL `https://dashscope.aliyuncs.com/compatible-mode/v1`
  // is wired in the Rust bridge so the user only needs an API key.
  ProviderMeta(
    provider: AiProvider.bailian,
    label: '百炼 (DashScope)',
    description: '阿里云百炼 / 通义千问 — Chinese flagship, OpenAI-compatible',
    models: [
      'qwen-max',
      'qwen-plus',
      'qwen-turbo',
      'qwen-long',
      'qwen3-coder-plus',
      'qwen2.5-72b-instruct',
      'qwen2.5-coder-32b-instruct',
    ],
    requiresApiKey: true,
  ),
  // v0.79.63: bring-your-own OpenAI-compatible endpoint. Useful for
  // self-hosted gateways (vLLM, LM Studio, LocalAI), OpenRouter, or
  // experimental providers not yet in the registry. Both apiKey and
  // baseUrl are required — the inline form gates Save on baseUrl
  // being a parseable URL and model name being non-empty.
  ProviderMeta(
    provider: AiProvider.custom,
    label: '自定义 (Custom)',
    description: '任意 OpenAI-compatible 端点 — 自填 base URL / API key / model',
    models: [],
    requiresApiKey: true,
    requiresBaseUrl: true,
  ),
];

ProviderMeta metaFor(AiProvider provider) =>
    kProviderRegistry.firstWhere((m) => m.provider == provider);
