import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Autocomplete suggestion source that feeds recent AI-extracted commands
/// into the terminal autocomplete engine.
///
/// Commands extracted from AI replies are scored higher than history.
class AiSuggestionSource {
  final List<String> _commands = [];
  static const _maxCommands = 50;

  /// Register commands extracted from a new AI message.
  void onAiMessage(List<String> commands) {
    for (final cmd in commands) {
      _commands.remove(cmd); // deduplicate
      _commands.insert(0, cmd);
    }
    while (_commands.length > _maxCommands) {
      _commands.removeLast();
    }
  }

  /// Suggest commands matching [prefix].
  List<String> suggest(String prefix) {
    if (prefix.isEmpty) return _commands.take(5).toList();
    return _commands.where((c) => c.startsWith(prefix)).take(10).toList();
  }

  void clear() => _commands.clear();
}

// ─── Riverpod provider ────────────────────────────────────────────────────────

final aiSuggestionSourceProvider =
    Provider<AiSuggestionSource>((ref) => AiSuggestionSource());
