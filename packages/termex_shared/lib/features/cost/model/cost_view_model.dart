/// View-model mirrors of the Rust cost DTOs in
/// `termex_core::cost`. Kept pure (no Riverpod, no FRB types) so
/// the widgets are testable in isolation and the data can be
/// composed from either local SQLite or a live daemon stream.
library;

/// Lifecycle kind of a recorded cost row.
enum CostKindVM {
  primaryAiCall,
  streamingSummary,
  toolUse;

  String get displayName => switch (this) {
        CostKindVM.primaryAiCall => 'AI call',
        CostKindVM.streamingSummary => 'Live summary',
        CostKindVM.toolUse => 'Tool use',
      };

  static CostKindVM parse(String s) => switch (s) {
        'primary_ai_call' => CostKindVM.primaryAiCall,
        'streaming_summary' => CostKindVM.streamingSummary,
        'tool_use' => CostKindVM.toolUse,
        _ => CostKindVM.primaryAiCall,
      };
}

/// Per-server roll-up used by the dashboard.
class ServerCostVM {
  final String serverId;
  /// Human label; usually the server name resolved client-side.
  /// Falls back to `serverId` when the lookup misses.
  final String serverName;
  final double costUsd;
  final int taskCount;
  const ServerCostVM({
    required this.serverId,
    required this.serverName,
    required this.costUsd,
    required this.taskCount,
  });
}

/// Top-N task spend row.
class TaskCostVM {
  final String taskId;
  final String promptPreview;
  final double costUsd;
  const TaskCostVM({
    required this.taskId,
    required this.promptPreview,
    required this.costUsd,
  });
}

class CostSummaryVM {
  final String periodLabel;
  final double totalUsd;
  final int taskCount;
  final int totalInputTokens;
  final int totalOutputTokens;
  final List<ServerCostVM> byServer;
  final List<TaskCostVM> topTasks;
  final Map<CostKindVM, double> byKind;
  const CostSummaryVM({
    required this.periodLabel,
    required this.totalUsd,
    required this.taskCount,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.byServer,
    required this.topTasks,
    required this.byKind,
  });

  factory CostSummaryVM.empty(String label) => CostSummaryVM(
        periodLabel: label,
        totalUsd: 0,
        taskCount: 0,
        totalInputTokens: 0,
        totalOutputTokens: 0,
        byServer: const [],
        topTasks: const [],
        byKind: const {},
      );
}

/// User caps modelled to match `termex_core::cost::UserCostCap`.
/// `null` on any field = unlimited.
class UserCostCapVM {
  final double? monthlyUsd;
  final double? singleTaskUsd;
  final double? perServerUsd;
  const UserCostCapVM({
    this.monthlyUsd,
    this.singleTaskUsd,
    this.perServerUsd,
  });

  bool get isUnlimited =>
      monthlyUsd == null && singleTaskUsd == null && perServerUsd == null;

  UserCostCapVM copyWith({
    Object? monthlyUsd = _unset,
    Object? singleTaskUsd = _unset,
    Object? perServerUsd = _unset,
  }) =>
      UserCostCapVM(
        monthlyUsd:
            identical(monthlyUsd, _unset) ? this.monthlyUsd : monthlyUsd as double?,
        singleTaskUsd: identical(singleTaskUsd, _unset)
            ? this.singleTaskUsd
            : singleTaskUsd as double?,
        perServerUsd: identical(perServerUsd, _unset)
            ? this.perServerUsd
            : perServerUsd as double?,
      );
}

const Object _unset = Object();

/// Format a USD amount for compact UI labels. Picks 4 dp under $0.01
/// (so token dust still shows a number), 3 dp under $1, 2 dp above.
String formatUsd(double amount) {
  if (amount.abs() < 0.0001) return '\$0.00';
  if (amount.abs() < 0.01) return '\$${amount.toStringAsFixed(4)}';
  if (amount.abs() < 1.0) return '\$${amount.toStringAsFixed(3)}';
  return '\$${amount.toStringAsFixed(2)}';
}

/// Format a token count as `12.3K` / `1.5M`. Used by the metrics
/// line so a 4-million-token row doesn't overflow the card.
String formatTokens(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '${(n / 1000000).toStringAsFixed(2)}M';
}
