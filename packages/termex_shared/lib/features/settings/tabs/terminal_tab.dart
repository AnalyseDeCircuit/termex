/// Terminal settings tab — scrollback, tab width, mouse, bell, cursor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../terminal/features/tmux/tmux_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/setting_row.dart';

class TerminalTab extends ConsumerWidget {
  const TerminalTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SettingRow(
          label: l10n.settingsTerminalScrollback,
          hint: l10n.settingsTerminalScrollbackHint,
          child: DropdownButton<int>(
            // 5000 is the legacy default from the v0.x Tauri build — keep
            // it as a selectable option so users whose DB still has that
            // value don't see the DropdownButton assertion firing.
            // Defensive `_coerce` snaps any other unknown value to the
            // nearest supported option to keep the dropdown stable as
            // the option set evolves.
            value: _coerceScrollback(settings.scrollbackLines),
            dropdownColor: context.colors.backgroundSecondary,
            items: [
              DropdownMenuItem(
                  value: 1000,
                  child: Text(l10n.settingsTerminalLinesOption('1,000'))),
              DropdownMenuItem(
                  value: 5000,
                  child: Text(l10n.settingsTerminalLinesOption('5,000'))),
              DropdownMenuItem(
                  value: 10000,
                  child: Text(l10n.settingsTerminalLinesOption('10,000'))),
              DropdownMenuItem(
                  value: 100000,
                  child: Text(l10n.settingsTerminalLinesOption('100,000'))),
            ],
            onChanged: (v) =>
                notifier.update(settings.copyWith(scrollbackLines: v!)),
            style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
          ),
        ),
        SettingRow(
          label: l10n.settingsTerminalTabWidth,
          child: DropdownButton<int>(
            value: settings.tabWidth,
            dropdownColor: context.colors.backgroundSecondary,
            items: [
              DropdownMenuItem(
                  value: 2,
                  child: Text(l10n.settingsTerminalSpacesOption('2'))),
              DropdownMenuItem(
                  value: 4,
                  child: Text(l10n.settingsTerminalSpacesOption('4'))),
              DropdownMenuItem(
                  value: 8,
                  child: Text(l10n.settingsTerminalSpacesOption('8'))),
            ],
            onChanged: (v) => notifier.update(settings.copyWith(tabWidth: v!)),
            style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
          ),
        ),
        SettingRow(
          label: l10n.settingsTerminalCursorShape,
          child: DropdownButton<CursorShape>(
            value: settings.cursorShape,
            dropdownColor: context.colors.backgroundSecondary,
            items: [
              DropdownMenuItem(
                  value: CursorShape.block,
                  child: Text(l10n.settingsTerminalCursorBlock)),
              DropdownMenuItem(
                  value: CursorShape.underline,
                  child: Text(l10n.settingsTerminalCursorUnderline)),
              DropdownMenuItem(
                  value: CursorShape.bar,
                  child: Text(l10n.settingsTerminalCursorBar)),
            ],
            onChanged: (v) =>
                notifier.update(settings.copyWith(cursorShape: v!)),
            style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
          ),
        ),
        SettingRow(
          label: l10n.settingsTerminalCursorBlink,
          child: Switch(
            value: settings.cursorBlink,
            onChanged: (v) =>
                notifier.update(settings.copyWith(cursorBlink: v)),
          ),
        ),
        const _TmuxModeRow(),
      ],
    );
  }
}

/// Snaps an arbitrary stored value to the nearest supported scrollback
/// option. Without this, DropdownButton asserts when `value` doesn't
/// match exactly one DropdownMenuItem — easy to hit on legacy DBs.
int _coerceScrollback(int stored) {
  const options = [1000, 5000, 10000, 100000];
  if (options.contains(stored)) return stored;
  // Closest by absolute distance — gives a reasonable mapping for any
  // future migration without losing the user's intent.
  int best = options.first;
  int bestDist = (stored - best).abs();
  for (final o in options.skip(1)) {
    final d = (stored - o).abs();
    if (d < bestDist) {
      best = o;
      bestDist = d;
    }
  }
  return best;
}

class _TmuxModeRow extends ConsumerWidget {
  const _TmuxModeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(tmuxModeProvider).valueOrNull ?? TmuxMode.auto;
    final l10n = AppLocalizations.of(context);
    return SettingRow(
      label: l10n.settingsTerminalTmux,
      hint: l10n.settingsTerminalTmuxHint,
      child: DropdownButton<TmuxMode>(
        value: mode,
        dropdownColor: context.colors.backgroundSecondary,
        items: TmuxMode.values
            .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            ref.read(tmuxModeProvider.notifier).set(v);
          }
        },
        style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
      ),
    );
  }
}
