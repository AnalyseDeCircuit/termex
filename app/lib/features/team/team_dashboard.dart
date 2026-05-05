import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/team_provider.dart';
import 'team_conflict_dialog.dart';
import 'team_invite_dialog.dart';
import 'team_members_table.dart';
import 'team_passphrase_dialog.dart';

class TeamDashboard extends ConsumerStatefulWidget {
  const TeamDashboard({super.key});

  @override
  ConsumerState<TeamDashboard> createState() => _TeamDashboardState();
}

class _TeamDashboardState extends ConsumerState<TeamDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final state = ref.read(teamProvider);
    if (!state.passphraseUnlocked) {
      if (!mounted) return;
      final unlocked = await showTeamPassphraseDialog(context);
      if (!unlocked || !mounted) return;
    }
    await ref.read(teamProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teamProvider);

    if (!state.passphraseUnlocked) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 40, color: TermexColors.textSecondary),
            const SizedBox(height: 12),
            Text('团队功能已锁定', style: TextStyle(fontSize: 14, color: TermexColors.textPrimary)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _init,
              style: ElevatedButton.styleFrom(
                backgroundColor: TermexColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('解锁团队协作'),
            ),
          ],
        ),
      );
    }

    if (state.isLoading) {
      return Center(child: CircularProgressIndicator(color: TermexColors.primary));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('团队成员',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TermexColors.textPrimary)),
                  Text('${state.members.length} 名成员',
                      style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
                ],
              ),
            ),
            // Sync status
            if (state.lastSyncAt != null)
              Text(
                '上次同步: ${_relTime(state.lastSyncAt!)}',
                style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
              ),
            const SizedBox(width: 8),
            _SyncButton(isSyncing: state.isSyncing),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => showTeamInviteDialog(context),
              icon: const Icon(Icons.person_add_outlined, size: 14),
              label: const Text('邀请成员', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: TermexColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Conflicts banner
        if (state.conflicts.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TermexColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TermexColors.warning.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: TermexColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      '${state.conflicts.length} 个同步冲突',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TermexColors.warning),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...state.conflicts.map((c) => _ConflictItem(conflict: c)),
              ],
            ),
          ),
        // Members table
        Container(
          decoration: BoxDecoration(
            color: TermexColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: TermexColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: const TeamMembersTable(),
        ),
        // Pending invites
        if (state.pendingInvites.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('待接受邀请',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TermexColors.textPrimary)),
          const SizedBox(height: 8),
          ...state.pendingInvites.map((inv) => _InviteChip(invite: inv)),
        ],
      ],
    );
  }

  String _relTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
      if (diff.inHours < 24) return '${diff.inHours} 小时前';
      return '${diff.inDays} 天前';
    } catch (_) {
      return iso;
    }
  }
}

class _SyncButton extends ConsumerWidget {
  final bool isSyncing;
  const _SyncButton({required this.isSyncing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: isSyncing ? null : () => ref.read(teamProvider.notifier).sync(),
      icon: isSyncing
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: TermexColors.textSecondary),
            )
          : const Icon(Icons.sync, size: 14),
      label: Text(isSyncing ? '同步中…' : '同步', style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: TermexColors.textSecondary,
        side: BorderSide(color: TermexColors.border),
        minimumSize: const Size(72, 32),
      ),
    );
  }
}

class _ConflictItem extends ConsumerWidget {
  final TeamConflict conflict;
  const _ConflictItem({required this.conflict});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${conflict.resourceType}: ${conflict.resourceName}',
              style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => TeamConflictDialog(conflict: conflict),
            ),
            style: TextButton.styleFrom(foregroundColor: TermexColors.warning),
            child: const Text('解决', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _InviteChip extends ConsumerWidget {
  final TeamInvite invite;
  const _InviteChip({required this.invite});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TermexColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline, size: 14, color: TermexColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(invite.email, style: TextStyle(fontSize: 12, color: TermexColors.textPrimary)),
          ),
          Text(invite.code,
              style: TextStyle(fontSize: 11, color: TermexColors.textSecondary, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, size: 14, color: TermexColors.textSecondary),
            onPressed: () => ref.read(teamProvider.notifier).revokeInvite(invite.code),
            tooltip: '撤销邀请',
          ),
        ],
      ),
    );
  }
}
