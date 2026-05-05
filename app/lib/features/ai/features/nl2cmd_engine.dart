import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/ai_stream_provider.dart';
import '../state/conversation_provider.dart';
import '../state/provider_config_provider.dart';

/// Converts natural language description to a shell command via the AI provider.
///
/// Wraps [AiStreamNotifier.send] with a structured prompt that instructs the
/// model to return ONLY the shell command (no explanation, no markdown).
class Nl2CmdEngine {
  final Ref _ref;

  Nl2CmdEngine(this._ref);

  /// Send an NL→command request and return the streaming reply message ID.
  Future<void> convert({
    required String description,
    String? currentDirectory,
    String? osHint,
  }) async {
    final config = _ref.read(providerConfigProvider).activeConfig;
    final convNotifier = _ref.read(conversationProvider.notifier);

    // Ensure we have an active conversation.
    final convState = _ref.read(conversationProvider);
    if (convState.activeConversationId == null) {
      convNotifier.createConversation(
        provider: config.provider,
        model: config.model,
        title: 'NL→CMD',
      );
    }

    final prompt = _buildPrompt(
      description: description,
      currentDirectory: currentDirectory,
      osHint: osHint,
    );

    await _ref.read(aiStreamProvider.notifier).send(userContent: prompt);
  }

  String _buildPrompt({
    required String description,
    String? currentDirectory,
    String? osHint,
  }) {
    final buf = StringBuffer();
    buf.writeln(
        'You are a shell command generator. Return ONLY the shell command, '
        'no explanation, no markdown, no backticks. '
        'If multiple commands are needed, join them with && or ;.');
    if (osHint != null) buf.writeln('OS: $osHint');
    if (currentDirectory != null) buf.writeln('CWD: $currentDirectory');
    buf.writeln();
    buf.writeln('Task: $description');
    return buf.toString();
  }
}

/// Riverpod provider for NL→CMD engine.
final nl2cmdEngineProvider = Provider<Nl2CmdEngine>((ref) => Nl2CmdEngine(ref));
