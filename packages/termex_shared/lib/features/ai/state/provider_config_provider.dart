import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_bridge/src/models.dart' as bridge_models;

import 'conversation_provider.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class AiProviderConfig {
  final AiProvider provider;
  final String model;
  final String? apiKey;
  final String? baseUrl;
  /// Max terminal scrollback lines to include as context (50/100/200/500).
  final int contextLines;

  const AiProviderConfig({
    required this.provider,
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.contextLines = 100,
  });

  AiProviderConfig copyWith({
    AiProvider? provider,
    String? model,
    String? apiKey,
    String? baseUrl,
    int? contextLines,
  }) =>
      AiProviderConfig(
        provider: provider ?? this.provider,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        contextLines: contextLines ?? this.contextLines,
      );
}

/// Default model for each provider.
const Map<AiProvider, String> kDefaultModel = {
  AiProvider.claude: 'claude-3-5-sonnet-20241022',
  AiProvider.openAi: 'gpt-4o',
  AiProvider.ollama: 'llama3',
  AiProvider.localLlama: 'llama3-8b-q4',
};

// ─── State ────────────────────────────────────────────────────────────────────

class ProviderConfigState {
  final AiProvider activeProvider;
  final Map<AiProvider, AiProviderConfig> configs;
  /// True while an API key verification call is in progress.
  final bool isVerifying;
  final String? verifyError;

  const ProviderConfigState({
    this.activeProvider = AiProvider.claude,
    this.configs = const {},
    this.isVerifying = false,
    this.verifyError,
  });

  AiProviderConfig get activeConfig =>
      configs[activeProvider] ??
      AiProviderConfig(
        provider: activeProvider,
        model: kDefaultModel[activeProvider]!,
      );

  ProviderConfigState copyWith({
    AiProvider? activeProvider,
    Map<AiProvider, AiProviderConfig>? configs,
    bool? isVerifying,
    String? verifyError,
    bool clearVerifyError = false,
  }) =>
      ProviderConfigState(
        activeProvider: activeProvider ?? this.activeProvider,
        configs: configs ?? this.configs,
        isVerifying: isVerifying ?? this.isVerifying,
        verifyError: clearVerifyError ? null : (verifyError ?? this.verifyError),
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

bridge_models.AiProvider _toBridgeProvider(AiProvider p) => switch (p) {
      AiProvider.claude => bridge_models.AiProvider.claude,
      AiProvider.openAi => bridge_models.AiProvider.openAi,
      AiProvider.ollama => bridge_models.AiProvider.ollama,
      AiProvider.localLlama => bridge_models.AiProvider.localLlama,
    };

AiProvider _fromBridgeProvider(bridge_models.AiProvider b) => switch (b) {
      bridge_models.AiProvider.claude => AiProvider.claude,
      bridge_models.AiProvider.openAi => AiProvider.openAi,
      bridge_models.AiProvider.ollama => AiProvider.ollama,
      bridge_models.AiProvider.localLlama => AiProvider.localLlama,
    };

class ProviderConfigNotifier extends Notifier<ProviderConfigState> {
  @override
  ProviderConfigState build() {
    Future.microtask(_loadAll);
    return const ProviderConfigState();
  }

  Future<void> _loadAll() async {
    final loaded = <AiProvider, AiProviderConfig>{};
    for (final p in AiProvider.values) {
      try {
        final remote = await bridge.aiLoadProviderConfig(
          provider: _toBridgeProvider(p),
        );
        if (remote != null) {
          loaded[p] = AiProviderConfig(
            provider: _fromBridgeProvider(remote.provider),
            model: remote.model,
            apiKey: remote.apiKey,
            baseUrl: remote.baseUrl,
            contextLines: remote.contextLines,
          );
        }
      } catch (_) {}
    }
    if (loaded.isNotEmpty) {
      state = state.copyWith(configs: loaded);
    }
  }

  void setActiveProvider(AiProvider provider) {
    state = state.copyWith(activeProvider: provider);
  }

  void updateConfig(AiProviderConfig config) {
    final updated = {...state.configs, config.provider: config};
    state = state.copyWith(configs: updated, clearVerifyError: true);
    bridge
        .aiSaveProviderConfig(
          config: bridge_models.AiProviderConfig(
            provider: _toBridgeProvider(config.provider),
            model: config.model,
            apiKey: config.apiKey,
            baseUrl: config.baseUrl,
            contextLines: config.contextLines,
          ),
        )
        .catchError((_) {});
  }

  Future<bool> verifyApiKey(AiProvider provider, String apiKey) async {
    state = state.copyWith(isVerifying: true, clearVerifyError: true);
    try {
      final ok = await bridge.aiVerifyApiKey(
        provider: _toBridgeProvider(provider),
        apiKey: apiKey,
      );
      state = state.copyWith(isVerifying: false);
      return ok;
    } catch (e) {
      state = state.copyWith(isVerifying: false, verifyError: e.toString());
      return false;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final providerConfigProvider =
    NotifierProvider<ProviderConfigNotifier, ProviderConfigState>(
  ProviderConfigNotifier.new,
);
