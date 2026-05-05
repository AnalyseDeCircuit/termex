/// Autocomplete suggestion sources.
///
/// Each source implements [SuggestionSource] and returns a list of
/// [AutocompleteSuggestion]s for a given prefix. Sources are ranked and
/// merged by [AutocompleteEngine].
library;

/// Category of a suggestion — used for display ordering and icons.
enum SuggestionKind {
  command,
  flag,
  path,
  variable,
  history,
}

/// A single autocomplete candidate.
class AutocompleteSuggestion {
  final String value;
  final String? description;
  final SuggestionKind kind;

  /// Score used for ranking; higher = shown first.
  final int score;

  const AutocompleteSuggestion({
    required this.value,
    this.description,
    required this.kind,
    this.score = 0,
  });
}

/// Contract for all autocomplete data sources.
abstract interface class SuggestionSource {
  /// Returns suggestions matching [prefix].
  ///
  /// [prefix] is the last token on the current line (may be empty).
  List<AutocompleteSuggestion> suggest(String prefix);
}

// ── Built-in sources ──────────────────────────────────────────────────────────

/// Common shell built-ins and frequently used commands.
class BuiltinCommandSource implements SuggestionSource {
  static const _commands = <String, String>{
    'ls': 'List directory contents',
    'cd': 'Change directory',
    'pwd': 'Print working directory',
    'mkdir': 'Make directory',
    'rmdir': 'Remove directory',
    'rm': 'Remove files or directories',
    'cp': 'Copy files',
    'mv': 'Move or rename files',
    'cat': 'Concatenate and print files',
    'less': 'View file contents (paginated)',
    'head': 'Output first lines of a file',
    'tail': 'Output last lines of a file',
    'grep': 'Search text patterns',
    'find': 'Search for files',
    'chmod': 'Change file permissions',
    'chown': 'Change file owner',
    'ln': 'Create links',
    'echo': 'Print text',
    'export': 'Set environment variable',
    'unset': 'Unset variable',
    'source': 'Execute commands from file',
    'sudo': 'Run as superuser',
    'ssh': 'Secure shell client',
    'scp': 'Secure copy',
    'rsync': 'Remote file sync',
    'curl': 'Transfer data with URLs',
    'wget': 'Download files',
    'tar': 'Archive files',
    'gzip': 'Compress files',
    'ps': 'List processes',
    'kill': 'Send signal to process',
    'top': 'System monitor',
    'df': 'Disk space usage',
    'du': 'Directory disk usage',
    'ping': 'Test network connectivity',
    'netstat': 'Network statistics',
    'ifconfig': 'Configure network interface',
    'git': 'Version control system',
    'gist': 'GitHub gist CLI',
    'docker': 'Container management',
    'kubectl': 'Kubernetes control',
    'vim': 'Text editor',
    'nano': 'Simple text editor',
    'man': 'Manual page viewer',
    'history': 'Command history',
    'exit': 'Exit shell',
    'clear': 'Clear terminal',
    'which': 'Locate a command',
    'type': 'Show command type',
    'alias': 'Create command alias',
  };

  @override
  List<AutocompleteSuggestion> suggest(String prefix) {
    if (prefix.isEmpty) return [];
    final lower = prefix.toLowerCase();
    return _commands.entries
        .where((e) => e.key.startsWith(lower))
        .map((e) => AutocompleteSuggestion(
              value: e.key,
              description: e.value,
              kind: SuggestionKind.command,
              score: e.key == prefix ? 100 : 50,
            ))
        .toList();
  }
}

/// AI-powered suggestion source — queries the AI autocomplete API.
///
/// Only triggers when [prefix] is ≥ 4 characters long and other sources
/// returned no results (signalled via [otherSourcesEmpty]).
class AiBackedSuggestionSource implements SuggestionSource {
  /// Commands recently suggested by AI, kept as a circular cache.
  final List<String> _cache = [];
  static const _maxCache = 50;

  /// Feed AI-generated suggestions into the local cache (called externally
  /// after an async AI response arrives).
  void feed(List<String> suggestions) {
    for (final s in suggestions) {
      _cache.remove(s);
      _cache.add(s);
      if (_cache.length > _maxCache) _cache.removeAt(0);
    }
  }

  void clear() => _cache.clear();

  @override
  List<AutocompleteSuggestion> suggest(String prefix) {
    if (prefix.length < 4) return [];
    return _cache
        .where((cmd) => cmd.startsWith(prefix) && cmd != prefix)
        .map((cmd) => AutocompleteSuggestion(
              value: cmd,
              description: 'AI suggestion',
              kind: SuggestionKind.command,
              score: 30,
            ))
        .toList();
  }
}

/// Source backed by the session's command history.
class HistorySource implements SuggestionSource {
  final List<String> _history;

  HistorySource(this._history);

  void addCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    _history.remove(trimmed);
    _history.add(trimmed);
    if (_history.length > 500) _history.removeAt(0);
  }

  @override
  List<AutocompleteSuggestion> suggest(String prefix) {
    if (prefix.isEmpty) return [];
    // Most recent first.
    return _history.reversed
        .where((cmd) => cmd.startsWith(prefix) && cmd != prefix)
        .take(20)
        .map((cmd) => AutocompleteSuggestion(
              value: cmd,
              kind: SuggestionKind.history,
              score: 80,
            ))
        .toList();
  }
}
