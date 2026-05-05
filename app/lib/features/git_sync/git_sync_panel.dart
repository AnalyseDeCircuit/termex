/// Git Sync dashboard (v0.47 spec §7.2).
///
/// Header shows the primary-repo status (from `servers.git_sync_*`) plus
/// Manual Sync button.  Below, a list of additional repos (V23
/// `git_sync_repos` table) each with independent controls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'conflict_resolver.dart';
import 'state/git_sync_provider.dart';

class GitSyncPanel extends ConsumerWidget {
  final String serverId;
  const GitSyncPanel({super.key, required this.serverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(gitSyncStatusProvider(serverId));
    final reposState = ref.watch(gitSyncReposProvider(serverId));

    return Container(
      color: TermexColors.backgroundPrimary,
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _PrimaryStatusHeader(serverId: serverId, status: status),
          const SizedBox(height: 24),
          Text('附加仓库',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: TermexColors.textPrimary,
              )),
          const SizedBox(height: 8),
          if (reposState.repos.isEmpty)
            Text('未配置附加仓库',
                style: TextStyle(
                  fontSize: 12,
                  color: TermexColors.textSecondary,
                ))
          else
            ...reposState.repos.map((r) => _RepoRow(serverId: serverId, repo: r)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showAddRepoDialog(context, ref),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('添加仓库', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddRepoDialog(BuildContext context, WidgetRef ref) async {
    final localCtrl = TextEditingController();
    final remoteCtrl = TextEditingController();
    GitSyncMode mode = GitSyncMode.notify;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 Git Sync 仓库'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: localCtrl,
                decoration: const InputDecoration(labelText: '本地路径'),
              ),
              TextField(
                controller: remoteCtrl,
                decoration: const InputDecoration(labelText: '远端 URL'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: GitSyncMode.values
                    .map((m) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(m.label),
                            selected: mode == m,
                            onSelected: (v) {
                              if (v) mode = m;
                            },
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('添加')),
        ],
      ),
    );

    if (ok == true && localCtrl.text.isNotEmpty && remoteCtrl.text.isNotEmpty) {
      await ref.read(gitSyncReposProvider(serverId).notifier).addRepo(
            localPath: localCtrl.text,
            remoteUrl: remoteCtrl.text,
            mode: mode,
          );
    }
  }
}

class _PrimaryStatusHeader extends ConsumerWidget {
  final String serverId;
  final GitSyncStatus status;

  const _PrimaryStatusHeader({required this.serverId, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gitSyncStatusProvider(serverId).notifier);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TermexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HealthDot(health: status.health),
              const SizedBox(width: 8),
              Text('Git Sync · ${status.health.label}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TermexColors.textPrimary,
                  )),
              const Spacer(),
              if (status.enabled)
                TextButton.icon(
                  onPressed: () => notifier.trigger(),
                  icon: const Icon(Icons.sync, size: 14),
                  label: const Text('手动同步', style: TextStyle(fontSize: 12)),
                )
              else
                TextButton.icon(
                  onPressed: () => _showEnableDialog(context, ref),
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: const Text('启用', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (status.enabled) ...[
            const SizedBox(height: 8),
            _row('本地', status.localPath),
            _row('远端', status.remoteUrl),
            if (status.lastSyncAt != null) _row('最近同步', status.lastSyncAt!),
            if (status.conflicts.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => showConflictResolver(context, status.conflicts),
                icon: const Icon(Icons.warning, size: 14),
                label: Text('解决冲突 (${status.conflicts.length})',
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, color: TermexColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 11,
                    color: TermexColors.textPrimary,
                    fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Future<void> _showEnableDialog(BuildContext context, WidgetRef ref) async {
    final localCtrl = TextEditingController();
    final remoteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('启用 Git Sync'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: localCtrl,
                decoration: const InputDecoration(labelText: '本地仓库路径'),
              ),
              TextField(
                controller: remoteCtrl,
                decoration: const InputDecoration(labelText: '远端 URL (git/ssh)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('启用')),
        ],
      ),
    );
    if (ok == true && localCtrl.text.isNotEmpty && remoteCtrl.text.isNotEmpty) {
      await ref
          .read(gitSyncStatusProvider(serverId).notifier)
          .enable(remoteCtrl.text, localCtrl.text);
    }
  }
}

class _HealthDot extends StatelessWidget {
  final GitSyncHealth health;
  const _HealthDot({required this.health});

  @override
  Widget build(BuildContext context) {
    final color = switch (health) {
      GitSyncHealth.synced => Colors.green,
      GitSyncHealth.pushing => Colors.amber,
      GitSyncHealth.pulling => Colors.amber,
      GitSyncHealth.conflict => Colors.red,
      GitSyncHealth.error => Colors.red,
      GitSyncHealth.disabled => TermexColors.textSecondary,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _RepoRow extends ConsumerWidget {
  final String serverId;
  final GitSyncRepo repo;
  const _RepoRow({required this.serverId, required this.repo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gitSyncReposProvider(serverId).notifier);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TermexColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(repo.localPath,
                    style: TextStyle(
                        fontSize: 12, color: TermexColors.textPrimary)),
                Text(repo.remoteUrl,
                    style: TextStyle(
                        fontSize: 10, color: TermexColors.textSecondary)),
                if (repo.lastError != null)
                  Text('错误: ${repo.lastError}',
                      style: const TextStyle(fontSize: 10, color: Colors.red)),
              ],
            ),
          ),
          DropdownButton<GitSyncMode>(
            value: repo.syncMode,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: GitSyncMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: (m) {
              if (m != null) notifier.updateMode(repo.id, m);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: () => notifier.removeRepo(repo.id),
          ),
        ],
      ),
    );
  }
}
