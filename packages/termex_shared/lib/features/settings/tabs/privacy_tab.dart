/// Privacy settings — history clearing + GDPR full erase.
///
/// v0.77.0 PC final parity: replaced stock Material `AlertDialog` /
/// `OutlinedButton` widgets with the project's own [`showTermexDialog`]
/// / [`TermexButton`] so the surface looks like the rest of the app.
/// Also added confirmation prompts for the three "clear …" actions —
/// they previously erased data on a single tap with no second chance.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../icons/termex_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialog.dart';
import '../../../widgets/text_field.dart';
import '../../../widgets/toast.dart';
import '../state/settings_provider.dart';

class PrivacyTab extends ConsumerWidget {
  const PrivacyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(settingsProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DangerSection(
          title: l10n.settingsPrivacyClearHistoryTitle,
          hint: l10n.settingsPrivacyClearHistoryHint,
          children: [
            _ClearButton(
              label: l10n.settingsPrivacyClearConnections,
              icon: TermexIcons.history,
              onTap: () => _confirmAndClear(
                context,
                title: l10n.settingsPrivacyClearConnections,
                message: l10n.settingsPrivacyClearConnectionsMsg,
                doClear: () async {
                  await notifier.clearConnectionHistory();
                  ToastController.success(l10n.settingsPrivacyClearedConnections);
                },
              ),
            ),
            _ClearButton(
              label: l10n.settingsPrivacyClearAi,
              icon: TermexIcons.ai,
              onTap: () => _confirmAndClear(
                context,
                title: l10n.settingsPrivacyClearAi,
                message: l10n.settingsPrivacyClearAiMsg,
                doClear: () async {
                  await notifier.clearAiConversations();
                  ToastController.success(l10n.settingsPrivacyClearedAi);
                },
              ),
            ),
            _ClearButton(
              label: l10n.settingsPrivacyClearSnippet,
              icon: TermexIcons.snippet,
              onTap: () => _confirmAndClear(
                context,
                title: l10n.settingsPrivacyClearSnippet,
                message: l10n.settingsPrivacyClearSnippetMsg,
                doClear: () async {
                  await notifier.clearSnippetStats();
                  ToastController.success(l10n.settingsPrivacyClearedSnippet);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _DangerSection(
          title: l10n.settingsPrivacyGdprTitle,
          hint: l10n.settingsPrivacyGdprHint,
          danger: true,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TermexButton(
                label: l10n.settingsPrivacyGdprButton,
                variant: ButtonVariant.danger,
                icon: const TermexIconWidget(TermexIcons.delete, size: 14),
                onPressed: () => _showGdprDialog(context, notifier),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmAndClear(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() doClear,
  }) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: l10n.settingsPrivacyConfirmClear,
      destructive: true,
    );
    if (ok == true) {
      await doClear();
    }
  }

  Future<void> _showGdprDialog(
    BuildContext context,
    SettingsNotifier notifier,
  ) async {
    final l10n = AppLocalizations.of(context);
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final ok = await showTermexDialog<bool>(
      context: context,
      title: l10n.settingsPrivacyGdprDialogTitle,
      size: DialogSize.small,
      body: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsPrivacyGdprDialogBody,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.settingsPrivacyMasterPassword,
                style: TextStyle(
                    fontSize: 11, color: context.colors.textSecondary)),
            const SizedBox(height: 4),
            TermexTextField(
              controller: passwordCtrl,
              obscureText: true,
              placeholder: l10n.settingsPrivacyMasterPassword,
            ),
            const SizedBox(height: 10),
            Text(l10n.settingsPrivacyConfirmTextLabel,
                style: TextStyle(
                    fontSize: 11, color: context.colors.textSecondary)),
            const SizedBox(height: 4),
            TermexTextField(
              controller: confirmCtrl,
              placeholder: 'DELETE ALL',
            ),
          ],
        ),
      ),
      actions: [
        Builder(
          builder: (ctx) => TermexButton(
            label: l10n.commonCancel,
            variant: ButtonVariant.ghost,
            onPressed: () =>
                Navigator.of(ctx, rootNavigator: true).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => TermexButton(
            label: l10n.settingsPrivacyErase,
            variant: ButtonVariant.danger,
            onPressed: () =>
                Navigator.of(ctx, rootNavigator: true).pop(true),
          ),
        ),
      ],
    );
    if (ok == true && context.mounted) {
      final success = await notifier.gdprEraseAll(
        passwordCtrl.text,
        confirmCtrl.text,
      );
      if (!success && context.mounted) {
        ToastController.error(l10n.settingsPrivacyEraseError);
      } else if (success && context.mounted) {
        ToastController.success(l10n.settingsPrivacyErased);
      }
    }
  }
}

// ─── Section card ─────────────────────────────────────────────────────────

class _DangerSection extends StatelessWidget {
  final String title;
  final String? hint;
  final List<Widget> children;
  final bool danger;

  const _DangerSection({
    required this.title,
    required this.children,
    this.hint,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger
            ? context.colors.danger.withValues(alpha: 0.05)
            : context.colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: danger
              ? context.colors.danger.withValues(alpha: 0.4)
              : context.colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: danger ? context.colors.danger : context.colors.textPrimary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ─── Clear-history button ─────────────────────────────────────────────────

class _ClearButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ClearButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? context.colors.backgroundTertiary
                  : const Color(0x00000000),
              border: Border.all(color: context.colors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                TermexIconWidget(
                  widget.icon,
                  size: 12,
                  color: context.colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                TermexIconWidget(
                  TermexIcons.chevronRight,
                  size: 12,
                  color: context.colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
