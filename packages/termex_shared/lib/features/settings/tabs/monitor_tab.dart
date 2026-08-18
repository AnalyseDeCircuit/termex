import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../state/settings_provider.dart';
import '../widgets/compact_controls.dart';
import '../widgets/setting_row.dart';

/// Settings → Monitor tab. Mirrors `MonitorTab.vue`:
/// sample interval radio, auto-start toggle, panel visibility checkboxes.
class MonitorTab extends ConsumerWidget {
  const MonitorTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SettingRow(
          label: l10n.monitorSampleInterval,
          hint: l10n.monitorSampleIntervalHint,
          child: _IntervalSelector(
            value: settings.monitorIntervalMs,
            onChanged: (v) =>
                notifier.update(settings.copyWith(monitorIntervalMs: v)),
          ),
        ),
        SettingRow(
          label: l10n.monitorAutoStartLabel,
          hint: l10n.monitorAutoStartHint,
          child: Align(
            alignment: Alignment.centerLeft,
            child: CompactSwitch(
              value: settings.monitorAutoStart,
              onChanged: (v) =>
                  notifier.update(settings.copyWith(monitorAutoStart: v)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SettingRow(
          label: l10n.monitorPanelDisplay,
          hint: l10n.monitorPanelDisplayHint,
          child: _PanelCheckboxes(
            settings: settings,
            onToggle: (key, value) {
              notifier.update(switch (key) {
                'cpu' => settings.copyWith(monitorShowCpu: value),
                'memory' => settings.copyWith(monitorShowMemory: value),
                'disk' => settings.copyWith(monitorShowDisk: value),
                'network' => settings.copyWith(monitorShowNetwork: value),
                'processes' =>
                  settings.copyWith(monitorShowProcesses: value),
                _ => settings,
              });
            },
          ),
        ),
      ],
    );
  }
}

class _IntervalSelector extends StatelessWidget {
  static const _options = [
    (1000, '1s'),
    (3000, '3s'),
    (5000, '5s'),
    (10000, '10s'),
  ];

  final int value;
  final ValueChanged<int> onChanged;

  const _IntervalSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: _options.map((opt) {
        final selected = opt.$1 == value;
        return _SegmentChip(
          label: opt.$2,
          selected: selected,
          onTap: () => onChanged(opt.$1),
        );
      }).toList(),
    );
  }
}

class _SegmentChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SegmentChip> createState() => _SegmentChipState();
}

class _SegmentChipState extends State<_SegmentChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? context.colors.primary.withOpacity(0.15)
                : (_hovered ? context.colors.backgroundTertiary : null),
            border: Border.all(
              color: selected ? context.colors.primary : context.colors.border,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              color: selected
                  ? context.colors.primary
                  : context.colors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelCheckboxes extends StatelessWidget {
  final AppSettings settings;
  final void Function(String key, bool value) onToggle;
  const _PanelCheckboxes({required this.settings, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _Check(
            label: 'CPU',
            value: settings.monitorShowCpu,
            onChanged: (v) => onToggle('cpu', v)),
        _Check(
            label: l10n.monitorMemory,
            value: settings.monitorShowMemory,
            onChanged: (v) => onToggle('memory', v)),
        _Check(
            label: l10n.monitorDisk,
            value: settings.monitorShowDisk,
            onChanged: (v) => onToggle('disk', v)),
        _Check(
            label: l10n.monitorNetwork,
            value: settings.monitorShowNetwork,
            onChanged: (v) => onToggle('network', v)),
        _Check(
            label: l10n.monitorProcesses,
            value: settings.monitorShowProcesses,
            onChanged: (v) => onToggle('processes', v)),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Check({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 16,
              color:
                  value ? context.colors.primary : context.colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style:
                  TextStyle(fontSize: 12, color: context.colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
