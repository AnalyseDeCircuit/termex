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
import 'package:termex_bridge/api.dart' as bridge;

import '../../l10n/app_localizations.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../icons/termex_icons.dart';
import '../../widgets/button.dart';
import '../../widgets/clickable.dart';
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
    final l10n = AppLocalizations.of(context);
    try {
      final changed = await bridge.teamSyncNow();
      if (!mounted) return;
      ToastController.success(l10n.teamSyncDoneCount(changed));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ToastController.error(l10n.teamSyncFailed(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<_TeamData>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(
            child: TermexIconWidget(
              TermexIcons.refresh,
              size: 18,
              color: ctx.colors.textMuted,
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
                    ToastController.success(l10n.teamApplied);
                    _reload();
                  } catch (e) {
                    if (!mounted) return;
                    ToastController.error(l10n.teamResolveFailed(e.toString()));
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
                  ToastController.success(l10n.teamRoleUpdated);
                  _reload();
                } catch (e) {
                  if (!mounted) return;
                  ToastController.error(l10n.teamUpdateFailed(e.toString()));
                }
              },
              onRemove: (m) async {
                try {
                  await bridge.teamRemoveMember(memberId: m.id);
                  if (!mounted) return;
                  ToastController.success(l10n.teamRemoved);
                  _reload();
                } catch (e) {
                  if (!mounted) return;
                  ToastController.error(l10n.teamRemoveFailed(e.toString()));
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
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: TermexSpacing.sm,
      runSpacing: TermexSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l10n.teamWorkspace,
          style: TermexTypography.body.copyWith(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: TermexSpacing.sm),
        _Badge(label: l10n.teamMemberBadge(memberCount), color: context.colors.primary),
        if (conflictCount > 0)
          _Badge(label: l10n.teamConflictBadge(conflictCount), color: context.colors.warning),
        TermexButton(
          label: l10n.teamV2InviteMember,
          variant: ButtonVariant.primary,
          onPressed: onInvite,
        ),
        TermexButton(
          label: l10n.teamDashSyncShort,
          variant: ButtonVariant.ghost,
          onPressed: onSync,
        ),
        TermexButton(
          label: l10n.teamChangePassphrase,
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
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: context.colors.border, width: 0.5),
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
              l10n.teamStatMembers,
              style: TermexTypography.caption.copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(height: 0.5, color: context.colors.border),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.all(TermexSpacing.md),
              child: Text(
                l10n.teamNoMembers,
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
    final l10n = AppLocalizations.of(context);
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
            ? context.colors.backgroundTertiary
            : const Color(0x00000000),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name.isEmpty ? l10n.teamUnnamed : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermexTypography.bodySmall.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (m.email.isNotEmpty)
                    Text(
                      m.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermexTypography.caption.copyWith(
                        color: context.colors.textMuted,
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
              Clickable(
                onTap: widget.onRemove,
                child: TermexIconWidget(
                  TermexIcons.delete,
                  size: 14,
                  color: context.colors.danger,
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
      return _Badge(label: 'Owner', color: context.colors.primary);
    }
    return Wrap(
      spacing: 4,
      children: [
        for (final r in [
          bridge.TeamRole.admin,
          bridge.TeamRole.member,
          bridge.TeamRole.viewer,
        ])
          Clickable(
            onTap: () => r == role ? null : onChanged(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: r == role
                    ? context.colors.primary.withValues(alpha: 0.12)
                    : const Color(0x00000000),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: r == role
                      ? context.colors.primary
                      : context.colors.border,
                  width: 0.5,
                ),
              ),
              child: Text(
                _label(r),
                style: TermexTypography.caption.copyWith(
                  fontSize: 10,
                  color: r == role
                      ? context.colors.primary
                      : context.colors.textMuted,
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
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: context.colors.warning, width: 0.5),
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
                TermexIconWidget(
                  TermexIcons.help,
                  size: 12,
                  color: context.colors.warning,
                ),
                const SizedBox(width: TermexSpacing.sm),
                Text(
                  l10n.teamPendingConflicts,
                  style: TermexTypography.caption.copyWith(
                    color: context.colors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: context.colors.border),
          ...conflicts.map(
            (c) => Padding(
              padding: const EdgeInsets.all(TermexSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.teamConflictServerField(c.serverId, c.field),
                    style: TermexTypography.caption.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: TermexSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: _ValueCell(
                          label: l10n.teamConflictLocal,
                          value: c.localValue,
                          onUse: () => onResolve(c, true),
                        ),
                      ),
                      const SizedBox(width: TermexSpacing.sm),
                      Expanded(
                        child: _ValueCell(
                          label: l10n.teamConflictRemote,
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
        padding: const EdgeInsets.all(TermexSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.backgroundTertiary,
          border: Border.all(color: context.colors.border, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TermexTypography.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TermexTypography.caption.copyWith(
                color: context.colors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: TermexSpacing.xs),
            Clickable(
              onTap: onUse,
              child: Text(
                l10n.teamUseThisValue,
                style: TermexTypography.caption.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ),
          ],
        ),
      );
  }
}

// ─── Dialogs ──────────────────────────────────────────────────────────────

Future<void> _showInviteDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  bridge.TeamRole role = bridge.TeamRole.member;
  bridge.TeamInvite? invite;
  String? errorMessage;
  bool generating = false;

  await showTermexDialog<void>(
    context: context,
    title: l10n.teamInviteNewMember,
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
                l10n.teamInviteDesc,
                style: TermexTypography.caption.copyWith(
                  color: ctx.colors.textSecondary,
                ),
              ),
              const SizedBox(height: TermexSpacing.md),
              Text(
                l10n.teamRole,
                style: TermexTypography.caption.copyWith(
                  color: ctx.colors.textSecondary,
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
                    Clickable(
                      onTap: () => setSt(() => role = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TermexSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: r == role
                              ? ctx.colors.primary.withValues(alpha: 0.12)
                              : const Color(0x00000000),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: r == role
                                ? ctx.colors.primary
                                : ctx.colors.border,
                          ),
                        ),
                        child: Text(
                          _RolePicker._label(r),
                          style: TermexTypography.caption.copyWith(
                            color: r == role
                                ? ctx.colors.primary
                                : ctx.colors.textPrimary,
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
                    color: ctx.colors.danger,
                  ),
                )
              else
                Text(
                  l10n.teamGenerateHint,
                  style: TermexTypography.caption.copyWith(
                    color: ctx.colors.textMuted,
                  ),
                ),
              const SizedBox(height: TermexSpacing.md),
              Row(
                children: [
                  TermexButton(
                    label: generating ? l10n.teamGenerating : l10n.teamV2InviteGenerate,
                    variant: ButtonVariant.primary,
                    onPressed: generating ? null : regen,
                  ),
                  const Spacer(),
                  Builder(
                    builder: (c) => TermexButton(
                      label: l10n.commonClose,
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: context.colors.border),
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
                    color: context.colors.textPrimary,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Clickable(
                onTap: () async {
                  await Clipboard.setData(
                      ClipboardData(text: invite.code));
                  ToastController.success(l10n.teamV2InviteCopied);
                },
                child: TermexIconWidget(
                  TermexIcons.copy,
                  size: 14,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.teamExpiresAt(invite.expiresAt),
            style: TermexTypography.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showPassphraseDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  String? errorMessage;
  await showTermexDialog<void>(
    context: context,
    title: l10n.teamVerifyPassphraseTitle,
    size: DialogSize.small,
    body: SizedBox(
      width: 360,
      child: StatefulBuilder(
        builder: (ctx, setSt) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.teamVerifyPassphraseDesc,
              style: TermexTypography.caption.copyWith(
                color: ctx.colors.textSecondary,
              ),
            ),
            const SizedBox(height: TermexSpacing.sm),
            TermexTextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              placeholder: l10n.teamPassphrasePlaceholder,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: TermexSpacing.xs),
              Text(
                errorMessage!,
                style: TermexTypography.caption.copyWith(
                  color: ctx.colors.danger,
                ),
              ),
            ],
            const SizedBox(height: TermexSpacing.md),
            Row(
              children: [
                Builder(
                  builder: (c) => TermexButton(
                    label: l10n.commonCancel,
                    variant: ButtonVariant.ghost,
                    onPressed: () =>
                        Navigator.of(c, rootNavigator: true).pop(),
                  ),
                ),
                const Spacer(),
                TermexButton(
                  label: l10n.teamVerify,
                  variant: ButtonVariant.primary,
                  onPressed: () async {
                    try {
                      final ok = await bridge.teamVerifyPassphrase(
                        passphrase: controller.text,
                      );
                      if (!ok) {
                        setSt(() => errorMessage = l10n.teamPassphraseIncorrect);
                        return;
                      }
                      if (ctx.mounted) {
                        Navigator.of(ctx, rootNavigator: true).pop();
                        ToastController.success(l10n.teamVerifyPassed);
                      }
                    } catch (e) {
                      setSt(() => errorMessage = l10n.teamVerifyFailed(e.toString()));
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.teamLoadFailed,
              style: TermexTypography.body.copyWith(
                color: context.colors.danger,
              ),
            ),
            const SizedBox(height: TermexSpacing.xs),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TermexTypography.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
            const SizedBox(height: TermexSpacing.sm),
            TermexButton(
              label: l10n.commonRetry,
              variant: ButtonVariant.ghost,
              onPressed: onRetry,
            ),
          ],
        ),
      );
  }
}
