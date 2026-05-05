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
];

ProviderMeta metaFor(AiProvider provider) =>
    kProviderRegistry.firstWhere((m) => m.provider == provider);
