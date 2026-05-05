/// Ghost text engine — real-time command-completion suggestions.
///
/// Maintains a prefix trie built from the most recent [maxHistorySize] shell
/// commands.  Given the current input line, [suggest] returns the single
/// best candidate to show as ghost text after the cursor.
///
/// # Key spec (§4.3 of v0.44.0 design doc)
/// | Key       | Behaviour                                              |
/// |-----------|--------------------------------------------------------|
/// | Tab       | Accept full ghost text (cursor moves to end of line)  |
/// | →         | Accept one word (to next space)                       |
/// | Esc       | Dismiss ghost text (no change to input buffer)        |
/// | Any other | Dismiss ghost text, key passes through normally       |
library;

/// A node in the prefix trie.
class _TrieNode {
  final Map<String, _TrieNode> children = {};
  String? terminal; // full command that ends at this node (the suggestion)
  int frequency = 0;
}

/// Result returned by [GhostTextEngine.suggest].
class GhostTextSuggestion {
  /// The full command string that matches the prefix.
  final String fullCommand;

  /// The suffix to display as ghost text after the cursor.
  /// This is `fullCommand.substring(prefix.length)`.
  final String ghostSuffix;

  const GhostTextSuggestion({
    required this.fullCommand,
    required this.ghostSuffix,
  });
}

/// Prefix-trie-based ghost text engine.
///
/// Thread safety: this class is not thread-safe.  Wrap in a provider /
/// ChangeNotifier if used from multiple isolates.
class GhostTextEngine {
  static const int maxHistorySize = 100;

  final _TrieNode _root = _TrieNode();
  final List<String> _history = [];

  // ── Mutation ─────────────────────────────────────────────────────────────

  /// Records a completed command in the trie.
  void recordCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;

    _history.add(trimmed);
    if (_history.length > maxHistorySize) {
      // Evict oldest — simple approach: rebuild trie from current window.
      _history.removeAt(0);
      _rebuildTrie();
      return;
    }

    _insert(trimmed);
  }

  /// Records a list of commands at once (e.g. on session restore).
  void recordAll(Iterable<String> commands) {
    for (final c in commands) {
      recordCommand(c);
    }
  }

  /// Clears all history and resets the trie.
  void clear() {
    _root.children.clear();
    _history.clear();
  }

  // ── Suggestion ────────────────────────────────────────────────────────────

  /// Returns the best ghost-text suggestion for [prefix], or `null` if none.
  GhostTextSuggestion? suggest(String prefix) {
    if (prefix.isEmpty) return null;

    // Walk the trie to the prefix endpoint.
    _TrieNode node = _root;
    for (final ch in prefix.split('')) {
      final child = node.children[ch];
      if (child == null) return null;
      node = child;
    }

    // Find the most-frequent terminal command in the subtree.
    final best = _bestTerminal(node);
    if (best == null) return null;

    return GhostTextSuggestion(
      fullCommand: best,
      ghostSuffix: best.substring(prefix.length),
    );
  }

  // ── Ghost text key handling ───────────────────────────────────────────────

  /// Returns the text to insert when the user accepts a single word (→).
  ///
  /// Given the current [inputLine] and [ghostSuffix], finds the first space
  /// in [ghostSuffix] and returns the portion up to (and including) it.
  /// If there is no space, returns the full [ghostSuffix].
  static String acceptOneWord(String inputLine, String ghostSuffix) {
    // Skip leading whitespace, then stop at the next space.
    var i = 0;
    while (i < ghostSuffix.length && ghostSuffix[i] == ' ') {
      i++;
    }
    final spaceIdx = ghostSuffix.indexOf(' ', i);
    if (spaceIdx == -1) return ghostSuffix;
    return ghostSuffix.substring(0, spaceIdx);
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _insert(String command) {
    _TrieNode node = _root;
    for (final ch in command.split('')) {
      node = node.children.putIfAbsent(ch, _TrieNode.new);
    }
    node.terminal = command;
    node.frequency++;
  }

  void _rebuildTrie() {
    _root.children.clear();
    for (final cmd in _history) {
      _insert(cmd);
    }
  }

  String? _bestTerminal(_TrieNode node) {
    if (node.terminal != null && node.children.isEmpty) {
      return node.terminal;
    }

    String? best = node.terminal;
    int bestFreq = node.frequency;

    void dfs(_TrieNode n) {
      if (n.terminal != null && n.frequency >= bestFreq) {
        best = n.terminal;
        bestFreq = n.frequency;
      }
      for (final child in n.children.values) {
        dfs(child);
      }
    }

    for (final child in node.children.values) {
      dfs(child);
    }
    return best;
  }
}
