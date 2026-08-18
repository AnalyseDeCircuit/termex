import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';
import '../state/keybinding_provider.dart';
import '../widgets/conflict_warning.dart';
import '../widgets/keybinding_capture.dart';

class KeybindingsTab extends ConsumerStatefulWidget {
  const KeybindingsTab({super.key});

  @override
  ConsumerState<KeybindingsTab> createState() => _KeybindingsTabState();
}

class _KeybindingsTabState extends ConsumerState<KeybindingsTab> {
  /// Identifies which row is currently in capture mode. `null` means
  /// no row is capturing. Lifting state to the tab gives us mutual
  /// exclusion for free — tapping a second row simply switches the
  /// active action and the previous row's `_KeybindingRow` rebuilds
  /// with `isCapturing = false`.
  String? _capturingAction;

  void _onTapRow(String action) {
    setState(() {
      _capturingAction = _capturingAction == action ? null : action;
    });
  }

  void _onCaptured(String action, String combo) {
    ref.read(keybindingProvider.notifier).setBinding(action, combo);
    setState(() => _capturingAction = null);
  }

  void _onCaptureCancel() {
    setState(() => _capturingAction = null);
  }

  void _confirmAndResetAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsKeybindingsResetTitle),
        content: Text(l10n.settingsKeybindingsResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.settingsKeybindingsReset),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(keybindingProvider.notifier).resetAll();
    setState(() => _capturingAction = null);
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l10n.keybindingsResetAll),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(keybindingProvider);
    final notifier = ref.read(keybindingProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        if (state.conflict != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: ConflictWarning(
              conflictingAction: state.conflict!,
              onDismiss: notifier.clearConflict,
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header row. The trailing slot mirrors the per-row reset
              // icon's footprint (~28px) so the three column Expanded
              // shares the same flex distribution as the data rows below
              // and "上下文" labels line up vertically. A long-press
              // affordance (tooltip on desktop, on-tap label on mobile)
              // discovers the "恢复默认" intent.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: _HeaderText(l10n.settingsKeybindingsColCommand)),
                    Expanded(
                        flex: 2,
                        child:
                            _HeaderText(l10n.settingsKeybindingsColShortcut)),
                    Expanded(
                        flex: 1,
                        child: _HeaderText(l10n.settingsKeybindingsColContext)),
                    _ResetAllIconButton(
                      tooltip: l10n.settingsKeybindingsResetTooltip,
                      onPressed: () => _confirmAndResetAll(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...state.bindings.map((b) {
                final label = _localizedActionLabel(b.action, l10n);
                return _KeybindingRow(
                  entry: b,
                  actionLabel: label.text,
                  actionUntranslated: label.untranslated,
                  untranslatedSuffix: l10n.keybindingsUntranslated,
                  isCapturing: _capturingAction == b.action,
                  onTapCapture: () => _onTapRow(b.action),
                  onCaptured: (combo) => _onCaptured(b.action, combo),
                  onCaptureCancel: _onCaptureCancel,
                  onReset: () => notifier.resetAction(b.action),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

/// Result of looking up a keybinding action's display label.
class _ActionLabel {
  final String text;

  /// `true` when the action key has no translation yet and the row
  /// should render the raw key with an italicised "(untranslated)"
  /// hint so the team can spot missing l10n entries at a glance.
  final bool untranslated;

  const _ActionLabel(this.text, {this.untranslated = false});
}

/// Map an internal action key (e.g. `reset_zoom`) to a localized label.
/// Returns `_ActionLabel(rawKey, untranslated: true)` for keys that
/// aren't in the switch — the UI surfaces those visually so adding a
/// new action without an ARB entry is a soft warning rather than a
/// silent fallback.
_ActionLabel _localizedActionLabel(String key, AppLocalizations l10n) {
  switch (key) {
    case 'new_tab':              return _ActionLabel(l10n.keybindingsNewTab);
    case 'close_tab':            return _ActionLabel(l10n.keybindingsCloseTab);
    case 'next_tab':             return _ActionLabel(l10n.keybindingsNextTab);
    case 'prev_tab':             return _ActionLabel(l10n.keybindingsPrevTab);
    case 'split_horizontal':     return _ActionLabel(l10n.keybindingsSplitHorizontal);
    case 'split_vertical':       return _ActionLabel(l10n.keybindingsSplitVertical);
    case 'close_pane':           return _ActionLabel(l10n.keybindingsClosePane);
    case 'focus_next_pane':      return _ActionLabel(l10n.keybindingsFocusPaneNext);
    case 'focus_prev_pane':      return _ActionLabel(l10n.keybindingsFocusPanePrev);
    case 'copy':                 return _ActionLabel(l10n.keybindingsCopy);
    case 'paste':                return _ActionLabel(l10n.keybindingsPaste);
    case 'select_all':           return _ActionLabel(l10n.keybindingsSelectAll);
    case 'zoom_in':              return _ActionLabel(l10n.keybindingsZoomIn);
    case 'zoom_out':             return _ActionLabel(l10n.keybindingsZoomOut);
    case 'reset_zoom':           return _ActionLabel(l10n.keybindingsResetZoom);
    case 'search_terminal':      return _ActionLabel(l10n.keybindingsSearch);
    case 'open_command_palette': return _ActionLabel(l10n.keybindingsCommandPalette);
    case 'ai_panel':             return _ActionLabel(l10n.keybindingsToggleAi);
    case 'ai_diagnose':          return _ActionLabel(l10n.keybindingsAiDiagnose);
    case 'nl2cmd':               return _ActionLabel(l10n.keybindingsNl2cmd);
    case 'sftp_panel':           return _ActionLabel(l10n.keybindingsSftpPanel);
    case 'sftp_upload':          return _ActionLabel(l10n.keybindingsSftpUpload);
    case 'sftp_download':        return _ActionLabel(l10n.keybindingsSftpDownload);
    case 'toggle_sftp':          return _ActionLabel(l10n.keybindingsToggleSftp);
    case 'open_settings':        return _ActionLabel(l10n.keybindingsOpenSettings);
    case 'quick_connect':        return _ActionLabel(l10n.keybindingsNewConnection);
    case 'reload_window':        return _ActionLabel(l10n.keybindingsReloadWindow);
    case 'toggle_fullscreen':    return _ActionLabel(l10n.keybindingsToggleFullscreen);
    default:
      return _ActionLabel(key, untranslated: true);
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: context.colors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// 14px restore icon with the same footprint as the per-row reset icon,
/// keeping the header's column flex distribution identical to the data
/// rows. Tooltip exposes the "恢复默认" intent.
class _ResetAllIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  const _ResetAllIconButton({
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Clickable(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Icon(
          Icons.restore,
          size: 14,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

class _KeybindingRow extends StatelessWidget {
  final KeybindingEntry entry;
  final String actionLabel;
  final bool actionUntranslated;
  final String untranslatedSuffix;
  final bool isCapturing;
  final VoidCallback onTapCapture;
  final void Function(String) onCaptured;
  final VoidCallback onCaptureCancel;
  final VoidCallback onReset;

  const _KeybindingRow({
    required this.entry,
    required this.actionLabel,
    required this.actionUntranslated,
    required this.untranslatedSuffix,
    required this.isCapturing,
    required this.onTapCapture,
    required this.onCaptured,
    required this.onCaptureCancel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _ActionLabelText(
              label: actionLabel,
              untranslated: actionUntranslated,
              untranslatedSuffix: untranslatedSuffix,
            ),
          ),
          Expanded(
            flex: 2,
            // Align(centerLeft) keeps the capture box sized to its
            // content instead of stretching the full flex-2 slot —
            // a 12-char combo like "⌘Shift+Alt+T" only needs ~110px,
            // so dragging the box across 200px+ on iPad made the
            // 上下文 column appear too far right and not line up
            // with the header label.
            child: Align(
              alignment: Alignment.centerLeft,
              child: KeybindingCapture(
                currentValue: entry.keyCombination,
                isCapturing: isCapturing,
                onTap: onTapCapture,
                onCaptured: onCaptured,
                onCaptureCancel: onCaptureCancel,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              entry.context,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 11, color: context.colors.textSecondary),
            ),
          ),
          Clickable(
            onTap: onReset,
            child: Icon(Icons.restore,
                size: 14, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Renders the action label. When [untranslated] is true, the label is
/// drawn in monospace + italic + muted grey, with a small "(untranslated)"
/// suffix below — that turns an unknown action key into a visible nudge
/// to add the corresponding ARB entry rather than letting it ship as a
/// silent raw `snake_case` identifier.
class _ActionLabelText extends StatelessWidget {
  final String label;
  final bool untranslated;
  final String untranslatedSuffix;

  const _ActionLabelText({
    required this.label,
    required this.untranslated,
    required this.untranslatedSuffix,
  });

  @override
  Widget build(BuildContext context) {
    if (!untranslated) {
      return Text(
        label,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontSize: 12,
          color: context.colors.textPrimary,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontStyle: FontStyle.italic,
            color: context.colors.textMuted,
          ),
        ),
        Text(
          untranslatedSuffix,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: context.colors.textMuted,
          ),
        ),
      ],
    );
  }
}
