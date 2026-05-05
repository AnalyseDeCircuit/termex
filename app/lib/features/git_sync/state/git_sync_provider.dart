/// Git Sync state (v0.47 spec §7).
///
/// Pure Dart mirror of the FRB DTOs defined in
/// `crates/termex-flutter-bridge/src/api/git_sync.rs`.  UI components read
/// status via `gitSyncStatusProvider` (family keyed by server_id) and manage
/// multi-repo through `gitSyncReposProvider`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum GitSyncMode { notify, auto, manual }

extension GitSyncModeLabel on GitSyncMode {
  String get label => switch (this) {
        GitSyncMode.notify => '通知',
        GitSyncMode.auto => '自动',
        GitSyncMode.manual => '手动',
      };

  String get asString => switch (this) {
        GitSyncMode.notify => 'notify',
        GitSyncMode.auto => 'auto',
        GitSyncMode.manual => 'manual',
      };

  static GitSyncMode parse(String s) {
    return switch (s) {
      'auto' => GitSyncMode.auto,
      'manual' => GitSyncMode.manual,
      _ => GitSyncMode.notify,
    };
  }
}

enum GitSyncHealth { synced, pushing, pulling, conflict, error, disabled }

extension GitSyncHealthLabel on GitSyncHealth {
  String get label => switch (this) {
        GitSyncHealth.synced => '已同步',
        GitSyncHealth.pushing => '推送中',
        GitSyncHealth.pulling => '拉取中',
        GitSyncHealth.conflict => '冲突',
        GitSyncHealth.error => '错误',
        GitSyncHealth.disabled => '已禁用',
      };
}

// ─── Models ──────────────────────────────────────────────────────────────────

class GitSyncStatus {
  final String serverId;
  final bool enabled;
  final GitSyncHealth health;
  final GitSyncMode mode;
  final String localPath;
  final String remoteUrl;
  final String? lastSyncAt;
  final String? lastError;
  final int ahead;
  final int behind;
  final List<String> conflicts;

  const GitSyncStatus({
    required this.serverId,
    this.enabled = false,
    this.health = GitSyncHealth.disabled,
    this.mode = GitSyncMode.notify,
    this.localPath = '',
    this.remoteUrl = '',
    this.lastSyncAt,
    this.lastError,
    this.ahead = 0,
    this.behind = 0,
    this.conflicts = const [],
  });

  GitSyncStatus copyWith({
    bool? enabled,
    GitSyncHealth? health,
    GitSyncMode? mode,
    String? localPath,
    String? remoteUrl,
    String? lastSyncAt,
    String? lastError,
    int? ahead,
    int? behind,
    List<String>? conflicts,
  }) =>
      GitSyncStatus(
        serverId: serverId,
        enabled: enabled ?? this.enabled,
        health: health ?? this.health,
        mode: mode ?? this.mode,
        localPath: localPath ?? this.localPath,
        remoteUrl: remoteUrl ?? this.remoteUrl,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: lastError ?? this.lastError,
        ahead: ahead ?? this.ahead,
        behind: behind ?? this.behind,
        conflicts: conflicts ?? this.conflicts,
      );
}

class GitSyncRepo {
  final String id;
  final String serverId;
  final String localPath;
  final String remoteUrl;
  final GitSyncMode syncMode;
  final String? lastSyncAt;
  final String? lastError;

  const GitSyncRepo({
    required this.id,
    required this.serverId,
    required this.localPath,
    required this.remoteUrl,
    this.syncMode = GitSyncMode.notify,
    this.lastSyncAt,
    this.lastError,
  });

  GitSyncRepo copyWith({
    GitSyncMode? syncMode,
    String? lastSyncAt,
    String? lastError,
  }) =>
      GitSyncRepo(
        id: id,
        serverId: serverId,
        localPath: localPath,
        remoteUrl: remoteUrl,
        syncMode: syncMode ?? this.syncMode,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: lastError ?? this.lastError,
      );
}

// ─── Notifier: single-repo status per server ────────────────────────────────

class GitSyncStatusNotifier
    extends FamilyNotifier<GitSyncStatus, String> {
  @override
  GitSyncStatus build(String serverId) {
    return GitSyncStatus(serverId: serverId);
  }

  Future<void> enable(String remoteUrl, String localPath) async {
    state = state.copyWith(
      enabled: true,
      health: GitSyncHealth.synced,
      remoteUrl: remoteUrl,
      localPath: localPath,
    );
  }

  Future<void> disable() async {
    state = state.copyWith(
      enabled: false,
      health: GitSyncHealth.disabled,
    );
  }

  Future<void> trigger() async {
    if (!state.enabled) return;
    state = state.copyWith(
      health: GitSyncHealth.pulling,
      lastError: null,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = state.copyWith(
      health: GitSyncHealth.synced,
      lastSyncAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> setMode(GitSyncMode mode) async {
    state = state.copyWith(mode: mode);
  }

  void markConflict(List<String> files) {
    state = state.copyWith(
      health: GitSyncHealth.conflict,
      conflicts: files,
    );
  }
}

final gitSyncStatusProvider = NotifierProvider.family<
    GitSyncStatusNotifier, GitSyncStatus, String>(
  GitSyncStatusNotifier.new,
);

// ─── Multi-repo state ───────────────────────────────────────────────────────

class GitSyncReposState {
  final String serverId;
  final List<GitSyncRepo> repos;

  const GitSyncReposState({
    required this.serverId,
    this.repos = const [],
  });

  GitSyncReposState copyWith({List<GitSyncRepo>? repos}) =>
      GitSyncReposState(serverId: serverId, repos: repos ?? this.repos);
}

class GitSyncReposNotifier
    extends FamilyNotifier<GitSyncReposState, String> {
  @override
  GitSyncReposState build(String serverId) =>
      GitSyncReposState(serverId: serverId);

  Future<String> addRepo({
    required String localPath,
    required String remoteUrl,
    GitSyncMode mode = GitSyncMode.notify,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final repo = GitSyncRepo(
      id: id,
      serverId: state.serverId,
      localPath: localPath,
      remoteUrl: remoteUrl,
      syncMode: mode,
    );
    state = state.copyWith(repos: [...state.repos, repo]);
    return id;
  }

  Future<void> removeRepo(String id) async {
    state = state.copyWith(
      repos: state.repos.where((r) => r.id != id).toList(),
    );
  }

  Future<void> updateMode(String id, GitSyncMode mode) async {
    state = state.copyWith(
      repos: state.repos
          .map((r) => r.id == id ? r.copyWith(syncMode: mode) : r)
          .toList(),
    );
  }

  Future<void> recordResult(String id, {String? error}) async {
    state = state.copyWith(
      repos: state.repos
          .map((r) => r.id == id
              ? r.copyWith(
                  lastSyncAt: DateTime.now().toIso8601String(),
                  lastError: error,
                )
              : r)
          .toList(),
    );
  }
}

final gitSyncReposProvider = NotifierProvider.family<
    GitSyncReposNotifier, GitSyncReposState, String>(
  GitSyncReposNotifier.new,
);
