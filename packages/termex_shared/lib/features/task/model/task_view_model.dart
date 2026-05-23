/// View-model for a single task as displayed in mobile / desktop UI.
///
/// Plain immutable struct (no freezed dependency) — keeps the dev loop
/// fast and avoids build_runner churn for a model this simple.
library;

/// Mirror of `TaskStatus` in the daemon wire protocol; tagged with
/// snake_case for direct comparison with bridge DTO strings.
enum TaskStatus {
  pending,
  pendingConfirmation,
  running,
  succeeded,
  failed,
  cancelled;

  bool get isTerminal =>
      this == TaskStatus.succeeded ||
      this == TaskStatus.failed ||
      this == TaskStatus.cancelled;

  String get wireName {
    switch (this) {
      case TaskStatus.pending:
        return 'pending';
      case TaskStatus.pendingConfirmation:
        return 'pending_confirmation';
      case TaskStatus.running:
        return 'running';
      case TaskStatus.succeeded:
        return 'succeeded';
      case TaskStatus.failed:
        return 'failed';
      case TaskStatus.cancelled:
        return 'cancelled';
    }
  }

  static TaskStatus fromWire(String s) {
    switch (s) {
      case 'pending_confirmation':
        return TaskStatus.pendingConfirmation;
      case 'running':
        return TaskStatus.running;
      case 'succeeded':
        return TaskStatus.succeeded;
      case 'failed':
        return TaskStatus.failed;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.pending;
    }
  }
}

/// Mirror of `AiCliKind`.
enum AiCliKind {
  claudeCode,
  codex,
  aider,
  generic;

  String get displayName {
    switch (this) {
      case AiCliKind.claudeCode:
        return 'Claude Code';
      case AiCliKind.codex:
        return 'Codex';
      case AiCliKind.aider:
        return 'Aider';
      case AiCliKind.generic:
        return 'Shell';
    }
  }

  String get wireName {
    switch (this) {
      case AiCliKind.claudeCode:
        return 'claude_code';
      case AiCliKind.codex:
        return 'codex';
      case AiCliKind.aider:
        return 'aider';
      case AiCliKind.generic:
        return 'generic';
    }
  }

  static AiCliKind fromWire(String s) {
    switch (s) {
      case 'claude_code':
        return AiCliKind.claudeCode;
      case 'codex':
        return AiCliKind.codex;
      case 'aider':
        return AiCliKind.aider;
      default:
        return AiCliKind.generic;
    }
  }
}

class TaskViewModel {
  final String id;
  final String serverId;
  final String serverName;
  final String prompt;
  final TaskStatus status;
  final AiCliKind aiCliKind;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? exitCode;
  final String? outputTail;
  final List<ArtifactSummary> artifactSummaries;
  final int totalInputTokens;
  final int totalOutputTokens;
  final double? estimatedCostUsd;

  const TaskViewModel({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.prompt,
    required this.status,
    required this.aiCliKind,
    required this.startedAt,
    this.endedAt,
    this.exitCode,
    this.outputTail,
    this.artifactSummaries = const [],
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.estimatedCostUsd,
  });

  Duration get elapsed {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  /// Single-line elapsed display ("2m 14s" / "12s" / "1h 3m").
  String get elapsedHuman {
    final d = elapsed;
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  TaskViewModel copyWith({
    String? id,
    String? serverId,
    String? serverName,
    String? prompt,
    TaskStatus? status,
    AiCliKind? aiCliKind,
    DateTime? startedAt,
    DateTime? endedAt,
    int? exitCode,
    String? outputTail,
    List<ArtifactSummary>? artifactSummaries,
    int? totalInputTokens,
    int? totalOutputTokens,
    double? estimatedCostUsd,
  }) {
    return TaskViewModel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      prompt: prompt ?? this.prompt,
      status: status ?? this.status,
      aiCliKind: aiCliKind ?? this.aiCliKind,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      exitCode: exitCode ?? this.exitCode,
      outputTail: outputTail ?? this.outputTail,
      artifactSummaries: artifactSummaries ?? this.artifactSummaries,
      totalInputTokens: totalInputTokens ?? this.totalInputTokens,
      totalOutputTokens: totalOutputTokens ?? this.totalOutputTokens,
      estimatedCostUsd: estimatedCostUsd ?? this.estimatedCostUsd,
    );
  }
}

class ArtifactSummary {
  final String id;
  final String kind;
  final int sizeBytes;
  final DateTime createdAt;
  final String? preview;

  const ArtifactSummary({
    required this.id,
    required this.kind,
    required this.sizeBytes,
    required this.createdAt,
    this.preview,
  });
}
