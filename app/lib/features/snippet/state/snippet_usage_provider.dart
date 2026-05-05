/// Tracks snippet insertion / execution so the library can surface
/// "最近使用" / "最常使用" lists (v0.46 spec §7.4).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'snippet_provider.dart';

class UsageStats {
  final String snippetId;
  final int count;
  final DateTime lastUsed;

  const UsageStats({
    required this.snippetId,
    required this.count,
    required this.lastUsed,
  });

  UsageStats copyWith({int? count, DateTime? lastUsed}) => UsageStats(
        snippetId: snippetId,
        count: count ?? this.count,
        lastUsed: lastUsed ?? this.lastUsed,
      );
}

class SnippetUsageState {
  final Map<String, UsageStats> byId;

  const SnippetUsageState({this.byId = const {}});

  /// Top N snippets by total usage count.
  List<UsageStats> mostUsed({int top = 10}) {
    final list = byId.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return list.take(top).toList();
  }

  /// Top N snippets by recency of last use.
  List<UsageStats> recentlyUsed({int top = 10}) {
    final list = byId.values.toList()
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return list.take(top).toList();
  }

  SnippetUsageState copyWith({Map<String, UsageStats>? byId}) =>
      SnippetUsageState(byId: byId ?? this.byId);
}

class SnippetUsageNotifier extends Notifier<SnippetUsageState> {
  @override
  SnippetUsageState build() => const SnippetUsageState();

  /// Records one insertion for `snippetId`.  Also asks the snippet provider
  /// to bump the persisted `use_count` so the library view stays in sync.
  void recordUse(String snippetId) {
    final now = DateTime.now();
    final existing = state.byId[snippetId];
    final updated = existing == null
        ? UsageStats(snippetId: snippetId, count: 1, lastUsed: now)
        : existing.copyWith(count: existing.count + 1, lastUsed: now);

    final newMap = Map<String, UsageStats>.from(state.byId);
    newMap[snippetId] = updated;
    state = state.copyWith(byId: newMap);

    // Mirror to the main snippet provider (so the persisted count matches).
    try {
      ref.read(snippetProvider.notifier).incrementUsage(snippetId);
    } catch (_) {
      // Ignored — provider may not be listening in test mode.
    }
  }

  /// Clears usage statistics (used by the Privacy tab).
  void clear() {
    state = const SnippetUsageState();
  }
}

final snippetUsageProvider =
    NotifierProvider<SnippetUsageNotifier, SnippetUsageState>(
        SnippetUsageNotifier.new);
