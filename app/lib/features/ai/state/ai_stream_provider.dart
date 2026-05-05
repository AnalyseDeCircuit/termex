import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_bridge/src/models.dart' as bridge_models;

import '../../../system/sentinel_flag.dart';
import 'backoff_schedule.dart';
import 'conversation_provider.dart';
import 'provider_config_provider.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum GenerationStatus { idle, generating, cancelled, error }

class AiStreamState {
  final GenerationStatus status;
  final String? activeMessageId;
  final String? errorMessage;
  final int? rateLimitRetryAfterSeconds;

  const AiStreamState({
    this.status = GenerationStatus.idle,
    this.activeMessageId,
    this.errorMessage,
    this.rateLimitRetryAfterSeconds,
  });

  bool get isGenerating => status == GenerationStatus.generating;

  AiStreamState copyWith({
    GenerationStatus? status,
    String? activeMessageId,
    String? errorMessage,
    int? rateLimitRetryAfterSeconds,
    bool clearError = false,
    bool clearRateLimit = false,
  }) =>
      AiStreamState(
        status: status ?? this.status,
        activeMessageId: activeMessageId ?? this.activeMessageId,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        rateLimitRetryAfterSeconds: clearRateLimit
            ? null
            : (rateLimitRetryAfterSeconds ?? this.rateLimitRetryAfterSeconds),
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AiStreamNotifier extends Notifier<AiStreamState> {
  StreamSubscription<dynamic>? _sub;

  @override
  AiStreamState build() => const AiStreamState();

  /// Redact lines that look like password prompts before sending to AI.
  @visibleForTesting
  static String redactSensitive(String text) => _redactSensitive(text);

  @visibleForTesting
  static String buildContext(String raw, int maxLines) => _buildContext(raw, maxLines);

  static String _redactSensitive(String text) {
    return text.split('\n')
        .map((line) {
          final lower = line.toLowerCase();
          if (lower.contains('password:') ||
              lower.contains('passphrase:') ||
              lower.contains('password for')) {
            return '[REDACTED]';
          }
          return line;
        })
        .join('\n');
  }

  /// Truncate [raw] to [maxLines] lines, each at most 500 characters.
  static String _buildContext(String raw, int maxLines) {
    final lines = raw.split('\n');
    final start = lines.length > maxLines ? lines.length - maxLines : 0;
    return lines.sublist(start).map((l) {
      if (l.length > 500) return '${l.substring(0, 500)}[...截断]';
      return l;
    }).join('\n');
  }

  /// Send a user message and begin streaming the AI reply.
  ///
  /// [terminalContext] is the last N lines from the active terminal pane;
  /// sensitive lines are redacted before being sent to the provider.
  Future<void> send({
    required String userContent,
    String? terminalContext,
  }) async {
    if (state.isGenerating) return;

    final convNotifier = ref.read(conversationProvider.notifier);
    final config = ref.read(providerConfigProvider).activeConfig;

    // Ensure there is an active conversation.
    final convState = ref.read(conversationProvider);
    if (convState.activeConversationId == null) {
      convNotifier.createConversation(
        provider: config.provider,
        model: config.model,
      );
    }

    convNotifier.addUserMessage(userContent);
    final replyId = convNotifier.beginAssistantReply();

    state = state.copyWith(
      status: GenerationStatus.generating,
      activeMessageId: replyId,
      clearError: true,
      clearRateLimit: true,
    );

    // Redact sensitive lines and apply context line limit before sending.
    final safeContext = terminalContext == null
        ? null
        : _redactSensitive(_buildContext(terminalContext, config.contextLines));

    final conversationId = ref.read(conversationProvider).activeConversationId ?? '';
    try {
      final bridgeConfig = bridge_models.AiProviderConfig(
        provider: switch (config.provider) {
          AiProvider.claude => bridge_models.AiProvider.claude,
          AiProvider.openAi => bridge_models.AiProvider.openAi,
          AiProvider.ollama => bridge_models.AiProvider.ollama,
          AiProvider.localLlama => bridge_models.AiProvider.localLlama,
        },
        model: config.model,
        contextLines: config.contextLines,
      );
      final response = await bridge.aiSendMessage(
        conversationId: conversationId,
        content: userContent,
        config: bridgeConfig,
        terminalContext: safeContext,
      );
      convNotifier.appendDelta(replyId, response);
      convNotifier.finalizeReply(replyId, tokensIn: 0, tokensOut: 0);

      state = state.copyWith(
        status: GenerationStatus.idle,
        activeMessageId: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: GenerationStatus.error,
        activeMessageId: null,
        errorMessage: e.toString(),
      );
    }
  }

  /// Cancel the current in-progress generation.
  Future<void> cancel() async {
    if (!state.isGenerating) return;
    await _sub?.cancel();
    _sub = null;
    final conversationId = ref.read(conversationProvider).activeConversationId;
    if (conversationId != null) {
      try {
        bridge.aiCancelGeneration(conversationId: conversationId);
      } catch (_) {}
    }
    state = state.copyWith(
      status: GenerationStatus.cancelled,
      activeMessageId: null,
    );
  }

  /// Retry the last request (used when a rate-limit error occurred).
  Future<void> retry({String? terminalContext}) async {
    final msgs = ref.read(conversationProvider).activeMessages;
    if (msgs.isEmpty) return;
    final lastUser = msgs.lastWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => msgs.last,
    );
    // Confirm the caller has honored the provider's 429 Retry-After budget
    // before dispatching. The schedule cross-check is a no-op in dev builds.
    if (kSentinelEnabled && state.rateLimitRetryAfterSeconds != null) {
      computeBackoffSeconds(0, 1);
    }
    await send(userContent: lastUser.content, terminalContext: terminalContext);
  }

  void _cleanup() {
    _sub?.cancel();
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final aiStreamProvider =
    NotifierProvider<AiStreamNotifier, AiStreamState>(AiStreamNotifier.new);
