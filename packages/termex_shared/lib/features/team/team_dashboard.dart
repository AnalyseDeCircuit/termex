/// Team workspace dashboard: members, invites, conflicts, sync.
///
/// Mirrors the legacy Tauri/Vue `TeamTab.vue` + sub-components:
///   - MemberManager.vue → member list + role chip + remove action
///   - RoleEditor.vue → role dropdown next to each member
///   - InviteDialog.vue → "Generate invite" button → modal with code
///   - ConflictResolver.vue → list of pending sync conflicts + accept
///   - Sync-now button + passphrase verify hook
///
/// Backed by real FRB calls on [team.rs] — none are stubbed in OSS:
///   teamGetMembers / teamAddMember / teamRemoveMember / teamUpdateRole
///   teamInviteGenerate / teamInviteAccept / teamListConflicts
///   teamResolveConflict / teamSyncNow / teamVerifyPassphrase
///
/// v0.77.0 PC final parity: closes P0-2 ("Team UI 全部 stub 化").
library;

import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../icons/termex_icons.dart';
import '../../widgets/button.dart';
import '../../widgets/dialog.dart';
import '../../widgets/text_field.dart';
import '../../widgets/toast.dart';

class TeamDashboard extends ConsumerStatefulWidget {
  const TeamDashboard({super.key});

  @override
  ConsumerState<TeamDashboard> createState() => _TeamDashboardState();
}

class _TeamDashboardState extends ConsumerState<TeamDashboard> {
  late Future<_TeamData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TeamData> _load() async {
    final results = await Future.wait<dynamic>([
      bridge.teamGetMembers().catchError((_) => <bridge.TeamMember>[]),
      bridge.teamListConflicts().catchError((_) => <bridge.TeamConflict>[]),
    ]);
    return _TeamData(
      members: results[0] as List<bridge.TeamMember>,
      conflicts: results[1] as List<bridge.TeamConflict>,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _syncNow() async {
    try {
      final changed = await bridge.teamSyncNow();
      if (!mounted) return;
      ToastController.success('同步完成（$changed 项变更）');
      _reload();
    } catch (e) {
      if (!mounted) return;
      ToastController.error('同步失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TeamData>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: TermexIconWidget(
              TermexIcons.refresh,
              size: 18,
              color: TermexColors.textMuted,
            ),
          );
        }
        if (snap.hasError) {
          return _ErrorView(error: snap.error.toString(), onRetry: _reload);
        }
        final d = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(TermexSpacing.md),
          children: [
            _Toolbar(
              memberCount: d.members.length,
              conflictCount: d.conflicts.length,
              onSync: _syncNow,
              onInvite: () async {
                await _showInviteDialog(context);
              },
              onPassphrase: () async {
                await _showPassphraseDialog(context);
              },
            ),
            const SizedBox(height: TermexSpacing.md),
            if (d.conflicts.isNotEmpty) ...[
              _ConflictsSection(
                conflicts: d.conflicts,
                onResolve: (c, useLocal) async {
                  try {
                    await bridge.teamResolveConflict(
                      conflictId: c.id,
                      useLocal: useLocal,
                    );
                    if (!mounted) return;
                    ToastController.success('已应用');
                    _reload();
                  } catch (e) {
                    if (!mounted) return;
                    ToastController.error('解决失败：$e');
                  }
                },
              ),
              const SizedBox(height: TermexSpacing.md),
            ],
            _MembersSection(
              members: d.members,
              onRoleChanged: (m, r) async {
                try {
                  await bridge.teamUpdateRole(memberId: m.id, role: r);
                  if (!mounted) return;
                  ToastController.success('已更新角色');
                  _reload();
                } catch (e) {
                  if (!mounted) return;
                  ToastController.error('更新失败：$e');
                }
              },
              onRemove: (m) async {
                try {
                  await bridge.teamRemoveMember(memberId: m.id);
                  if (!mounted) return;
                  ToastController.success('已移除');
                  _reload();
                } catch (e) {
                  if (!mounted) return;
                  ToastController.error('移除失败：$e');
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _TeamData {
  final List<bridge.TeamMember> members;
  final List<bridge.TeamConflict> conflicts;
  const _TeamData({required this.members, required this.conflicts});
}

// ─── Toolbar ──────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final int memberCount;
  final int conflictCount;
  final VoidCallback onSync;
  final VoidCallback onInvite;
  final VoidCallback onPassphrase;

  const _Toolbar({
    required this.memberCount,
    required this.conflictCount,
    required this.onSync,
    required this.onInvite,
    required this.onPassphrase,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TermexSpacing.sm,
      runSpacing: TermexSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '团队工作区',
          style: TermexTypography.body.copyWith(
            color: TermexColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: TermexSpacing.sm),
        _Badge(label: '$memberCount 成员', color: TermexColors.primary),
        if (conflictCount > 0)
          _Badge(label: '$conflictCount 冲突', color: TermexColors.warning),
        TermexButton(
          label: '邀请成员',
          variant: ButtonVariant.primary,
          onPressed: onInvite,
        ),
        TermexButton(
          label: '同步',
          variant: ButtonVariant.ghost,
          onPressed: onSync,
        ),
        TermexButton(
          label: '修改口令',
          variant: ButtonVariant.ghost,
          onPressed: onPassphrase,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Text(
          label,
          style: TermexTypography.caption.copyWith(color: color),
        ),
      );
}

// ─── Members ──────────────────────────────────────────────────────────────

class _MembersSection extends StatelessWidget {
  final List<bridge.TeamMember> members;
  final void Function(bridge.TeamMember, bridge.TeamRole) onRoleChanged;
  final void Function(bridge.TeamMember) onRemove;

  const _MembersSection({
    required this.members,
    required this.onRoleChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border.all(color: TermexColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TermexSpacing.md,
              vertical: TermexSpacing.sm,
            ),
            child: Text(
              '成员',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(height: 0.5, color: TermexColors.border),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(TermexSpacing.md),
              child: Text(
                '暂无成员（生成邀请码后即可加入）',
                style: TermexTypography.caption,
                textAlign: TextAlign.center,
              ),
            )
          else
            ...members.map((m) => _MemberRow(
                  member: m,
                  onRoleChanged: (r) => onRoleChanged(m, r),
                  onRemove: () => onRemove(m),
                )),
        ],
      ),
    );
  }
}

class _MemberRow extends StatefulWidget {
  final bridge.TeamMember member;
  final ValueChanged<bridge.TeamRole> onRoleChanged;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.member,
    required this.onRoleChanged,
    required this.onRemove,
  });

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.md,
          vertical: TermexSpacing.sm,
        ),
        color: _hovered
            ? TermexColors.backgroundTertiary
            : const Color(0x00000000),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name.isEmpty ? '(未命名)' : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermexTypography.bodySmall.copyWith(
                      color: TermexColors.textPrimary,
                    ),
                  ),
                  if (m.email.isNotEmpty)
                    Text(
                      m.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermexTypography.caption.copyWith(
                        color: TermexColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            _RolePicker(
              role: m.role,
              onChanged: widget.onRoleChanged,
            ),
            const SizedBox(width: TermexSpacing.sm),
            if (m.role != bridge.TeamRole.owner)
              GestureDetector(
                onTap: widget.onRemove,
                child: const TermexIconWidget(
                  TermexIcons.delete,
                  size: 14,
                  color: TermexColors.danger,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  final bridge.TeamRole role;
  final ValueChanged<bridge.TeamRole> onChanged;

  const _RolePicker({required this.role, required this.onChanged});

  static String _label(bridge.TeamRole r) => switch (r) {
        bridge.TeamRole.owner => 'Owner',
        bridge.TeamRole.admin => 'Admin',
        bridge.TeamRole.member => 'Member',
        bridge.TeamRole.viewer => 'Viewer',
      };

  @override
  Widget build(BuildContext context) {
    if (role == bridge.TeamRole.owner) {
      return _Badge(label: 'Owner', color: TermexColors.primary);
    }
    return Wrap(
      spacing: 4,
      children: [
        for (final r in [
          bridge.TeamRole.admin,
          bridge.TeamRole.member,
          bridge.TeamRole.viewer,
        ])
          GestureDetector(
            onTap: () => r == role ? null : onChanged(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: r == role
                    ? TermexColors.primary.withValues(alpha: 0.12)
                    : const Color(0x00000000),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: r == role ? TermexColors.primary : TermexColors.border,
                  width: 0.5,
                ),
              ),
              child: Text(
                _label(r),
                style: TermexTypography.caption.copyWith(
                  fontSize: 10,
                  color: r == role
                      ? TermexColors.primary
                      : TermexColors.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Conflicts ────────────────────────────────────────────────────────────

class _ConflictsSection extends StatelessWidget {
  final List<bridge.TeamConflict> conflicts;
  final void Function(bridge.TeamConflict, bool useLocal) onResolve;

  const _ConflictsSection({
    required this.conflicts,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border.all(color: TermexColors.warning, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TermexSpacing.md,
              vertical: TermexSpacing.sm,
            ),
            child: Row(
              children: [
                const TermexIconWidget(
                  TermexIcons.help,
                  size: 12,
                  color: TermexColors.warning,
                ),
                const SizedBox(width: TermexSpacing.sm),
                Text(
                  '待解决的同步冲突',
                  style: TermexTypography.caption.copyWith(
                    color: TermexColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: TermexColors.border),
          ...conflicts.map(
            (c) => Padding(
              padding: const EdgeInsets.all(TermexSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '服务器 ${c.serverId} · 字段 ${c.field}',
                    style: TermexTypography.caption.copyWith(
                      color: TermexColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: TermexSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: _ValueCell(
                          label: '本地',
                          value: c.localValue,
                          onUse: () => onResolve(c, true),
                        ),
                      ),
                      const SizedBox(width: TermexSpacing.sm),
                      Expanded(
                        child: _ValueCell(
                          label: '远端',
                          value: c.remoteValue,
                          onUse: () => onResolve(c, false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onUse;

  const _ValueCell({
    required this.label,
    required this.value,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(TermexSpacing.sm),
        decoration: BoxDecoration(
          color: TermexColors.backgroundTertiary,
          border: Border.all(color: TermexColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: TermexSpacing.xs),
            GestureDetector(
              onTap: onUse,
              child: Text(
                '使用此值',
                style: TermexTypography.caption.copyWith(
                  color: TermexColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Dialogs ──────────────────────────────────────────────────────────────

Future<void> _showInviteDialog(BuildContext context) async {
  bridge.TeamRole role = bridge.TeamRole.member;
  bridge.TeamInvite? invite;
  String? errorMessage;
  bool generating = false;

  await showTermexDialog<void>(
    context: context,
    title: '邀请新成员',
    size: DialogSize.medium,
    body: SizedBox(
      width: 420,
      child: StatefulBuilder(
        builder: (ctx, setSt) {
          Future<void> regen() async {
            setSt(() {
              generating = true;
              errorMessage = null;
            });
            try {
              final v = await bridge.teamInviteGenerate(
                role: role,
                expiresHours: 72,
              );
              setSt(() {
                invite = v;
                generating = false;
              });
            } catch (e) {
              setSt(() {
                errorMessage = e.toString();
                generating = false;
              });
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '为新成员生成一次性邀请码（72 小时内有效）。',
                style: TermexTypography.caption.copyWith(
                  color: TermexColors.textSecondary,
                ),
              ),
              const SizedBox(height: TermexSpacing.md),
              Text(
                '角色',
                style: TermexTypography.caption.copyWith(
                  color: TermexColors.textSecondary,
                ),
              ),
              const SizedBox(height: TermexSpacing.xs),
              Wrap(
                spacing: 4,
                children: [
                  for (final r in [
                    bridge.TeamRole.admin,
                    bridge.TeamRole.member,
                    bridge.TeamRole.viewer,
                  ])
                    GestureDetector(
                      onTap: () => setSt(() => role = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TermexSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: r == role
                              ? TermexColors.primary.withValues(alpha: 0.12)
                              : const Color(0x00000000),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: r == role
                                ? TermexColors.primary
                                : TermexColors.border,
                          ),
                        ),
                        child: Text(
                          _RolePicker._label(r),
                          style: TermexTypography.caption.copyWith(
                            color: r == role
                                ? TermexColors.primary
                                : TermexColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: TermexSpacing.md),
              if (invite != null)
                _InviteCodeBox(invite: invite!)
              else if (errorMessage != null)
                Text(
                  errorMessage!,
                  style: TermexTypography.caption.copyWith(
                    color: TermexColors.danger,
                  ),
                )
              else
                Text(
                  '点击下方按钮生成邀请码。',
                  style: TermexTypography.caption.copyWith(
                    color: TermexColors.textMuted,
                  ),
                ),
              const SizedBox(height: TermexSpacing.md),
              Row(
                children: [
                  TermexButton(
                    label: generating ? '生成中…' : '生成邀请码',
                    variant: ButtonVariant.primary,
                    onPressed: generating ? null : regen,
                  ),
                  const Spacer(),
                  Builder(
                    builder: (c) => TermexButton(
                      label: '关闭',
                      variant: ButtonVariant.ghost,
                      onPressed: () =>
                          Navigator.of(c, rootNavigator: true).pop(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _InviteCodeBox extends StatelessWidget {
  final bridge.TeamInvite invite;
  const _InviteCodeBox({required this.invite});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.md),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border.all(color: TermexColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  invite.code,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textPrimary,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(
                      ClipboardData(text: invite.code));
                  ToastController.success('已复制');
                },
                child: const TermexIconWidget(
                  TermexIcons.copy,
                  size: 14,
                  color: TermexColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '过期：${invite.expiresAt}',
            style: TermexTypography.caption.copyWith(
              color: TermexColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showPassphraseDialog(BuildContext context) async {
  final controller = TextEditingController();
  String? errorMessage;
  await showTermexDialog<void>(
    context: context,
    title: '验证团队口令',
    size: DialogSize.small,
    body: SizedBox(
      width: 360,
      child: StatefulBuilder(
        builder: (ctx, setSt) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '输入团队加密口令验证当前会话。',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(height: TermexSpacing.sm),
            TermexTextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              placeholder: '口令',
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: TermexSpacing.xs),
              Text(
                errorMessage!,
                style: TermexTypography.caption.copyWith(
                  color: TermexColors.danger,
                ),
              ),
            ],
            const SizedBox(height: TermexSpacing.md),
            Row(
              children: [
                Builder(
                  builder: (c) => TermexButton(
                    label: '取消',
                    variant: ButtonVariant.ghost,
                    onPressed: () =>
                        Navigator.of(c, rootNavigator: true).pop(),
                  ),
                ),
                const Spacer(),
                TermexButton(
                  label: '验证',
                  variant: ButtonVariant.primary,
                  onPressed: () async {
                    try {
                      final ok = await bridge.teamVerifyPassphrase(
                        passphrase: controller.text,
                      );
                      if (!ok) {
                        setSt(() => errorMessage = '口令不正确');
                        return;
                      }
                      if (ctx.mounted) {
                        Navigator.of(ctx, rootNavigator: true).pop();
                        ToastController.success('验证通过');
                      }
                    } catch (e) {
                      setSt(() => errorMessage = '验证失败：$e');
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Error ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载团队信息失败',
              style: TermexTypography.body.copyWith(
                color: TermexColors.danger,
              ),
            ),
            const SizedBox(height: TermexSpacing.xs),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
            const SizedBox(height: TermexSpacing.sm),
            TermexButton(
              label: '重试',
              variant: ButtonVariant.ghost,
              onPressed: onRetry,
            ),
          ],
        ),
      );
}
