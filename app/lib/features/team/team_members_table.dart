import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/team_provider.dart';

class TeamMembersTable extends ConsumerWidget {
  const TeamMembersTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamProvider).members;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: TermexColors.backgroundTertiary,
          child: Row(
            children: [
              _Header('成员', flex: 3),
              _Header('角色', flex: 2),
              _Header('加入时间', flex: 2),
              _Header('状态', flex: 1),
              const SizedBox(width: 48),
            ],
          ),
        ),
        const Divider(height: 1),
        ...members.map((m) => _MemberRow(member: m)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  final int flex;
  const _Header(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: TermexColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _MemberRow extends ConsumerWidget {
  final TeamMember member;
  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(teamProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Avatar + email
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _Avatar(email: member.email, isOnline: member.isOnline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member.email,
                    style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Role dropdown
          Expanded(
            flex: 2,
            child: member.role == TeamRole.owner
                ? _RoleBadge(role: member.role)
                : DropdownButton<TeamRole>(
                    value: member.role,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    dropdownColor: TermexColors.backgroundSecondary,
                    style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
                    items: [TeamRole.admin, TeamRole.member, TeamRole.viewer]
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: _RoleBadge(role: r),
                            ))
                        .toList(),
                    onChanged: (r) => notifier.changeRole(member.id, r!),
                  ),
          ),
          // Joined
          Expanded(
            flex: 2,
            child: Text(
              _fmtDate(member.joinedAt),
              style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
            ),
          ),
          // Online status
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: member.isOnline ? TermexColors.success : TermexColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  member.isOnline ? '在线' : '离线',
                  style: TextStyle(
                    fontSize: 11,
                    color: member.isOnline ? TermexColors.success : TermexColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          if (member.role != TeamRole.owner)
            SizedBox(
              width: 48,
              child: IconButton(
                icon: Icon(Icons.remove_circle_outline, size: 16, color: TermexColors.danger),
                onPressed: () => _confirmRemove(context, ref, member),
                tooltip: '移除成员',
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)}';
    } catch (_) {
      return iso;
    }
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, TeamMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: Text('确认移除', style: TextStyle(color: TermexColors.danger, fontSize: 14)),
        content: Text('确定要移除 ${m.email} 吗？', style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: TermexColors.danger),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(teamProvider.notifier).removeMember(m.id);
    }
  }
}

class _Avatar extends StatelessWidget {
  final String email;
  final bool isOnline;
  const _Avatar({required this.email, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final initials = email.isNotEmpty ? email[0].toUpperCase() : '?';
    return Stack(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: TermexColors.primary.withOpacity(0.2),
          child: Text(initials, style: TextStyle(fontSize: 12, color: TermexColors.primary, fontWeight: FontWeight.w600)),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: TermexColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: TermexColors.backgroundSecondary, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final TeamRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    final label = TeamMember(id: '', email: '', role: role, joinedAt: '').roleLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
