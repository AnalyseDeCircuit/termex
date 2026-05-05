import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
import '../state/settings_provider.dart';

class AppearanceTab extends ConsumerWidget {
  const AppearanceTab({super.key});

  static const _colorSchemes = [
    'github-dark', 'dracula', 'gruvbox', 'solarized-dark', 'one-dark', 'monokai',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Section(title: '主题', children: [
          _RadioRow<ThemeMode>(
            label: '跟随系统',
            value: ThemeMode.system,
            groupValue: settings.themeMode,
            onChanged: (v) => notifier.update(settings.copyWith(themeMode: v)),
          ),
          _RadioRow<ThemeMode>(
            label: '浅色',
            value: ThemeMode.light,
            groupValue: settings.themeMode,
            onChanged: (v) => notifier.update(settings.copyWith(themeMode: v)),
          ),
          _RadioRow<ThemeMode>(
            label: '深色',
            value: ThemeMode.dark,
            groupValue: settings.themeMode,
            onChanged: (v) => notifier.update(settings.copyWith(themeMode: v)),
          ),
        ]),
        _Section(title: '终端配色方案', children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colorSchemes.map((scheme) {
              final isSelected = settings.colorScheme == scheme;
              return GestureDetector(
                onTap: () => notifier.update(settings.copyWith(colorScheme: scheme)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TermexColors.primary.withOpacity(0.15)
                        : TermexColors.backgroundTertiary,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSelected ? TermexColors.primary : TermexColors.border,
                    ),
                  ),
                  child: Text(
                    scheme,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? TermexColors.primary
                          : TermexColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ]),
        _Section(title: '字体', children: [
          _LabeledRow(
            label: '字体大小',
            child: Row(
              children: [
                Text('${settings.fontSize.round()}', style: TextStyle(fontSize: 12, color: TermexColors.textPrimary)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: settings.fontSize,
                    min: 10,
                    max: 22,
                    divisions: 12,
                    activeColor: TermexColors.primary,
                    onChanged: (v) => notifier.update(settings.copyWith(fontSize: v)),
                  ),
                ),
              ],
            ),
          ),
        ]),
        _Section(title: '光标', children: [
          _RadioRow<CursorShape>(
            label: '方块',
            value: CursorShape.block,
            groupValue: settings.cursorShape,
            onChanged: (v) => notifier.update(settings.copyWith(cursorShape: v)),
          ),
          _RadioRow<CursorShape>(
            label: '下划线',
            value: CursorShape.underline,
            groupValue: settings.cursorShape,
            onChanged: (v) => notifier.update(settings.copyWith(cursorShape: v)),
          ),
          _RadioRow<CursorShape>(
            label: '竖线',
            value: CursorShape.bar,
            groupValue: settings.cursorShape,
            onChanged: (v) => notifier.update(settings.copyWith(cursorShape: v)),
          ),
          _ToggleRow(
            label: '光标闪烁',
            value: settings.cursorBlink,
            onChanged: (v) => notifier.update(settings.copyWith(cursorBlink: v)),
          ),
        ]),
        _Section(title: '语言', children: [
          _RadioRow<Language>(
            label: '中文',
            value: Language.zhCN,
            groupValue: settings.language,
            onChanged: (v) => notifier.update(settings.copyWith(language: v)),
          ),
          _RadioRow<Language>(
            label: 'English',
            value: Language.enUS,
            groupValue: settings.language,
            onChanged: (v) => notifier.update(settings.copyWith(language: v)),
          ),
        ]),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: TermexColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _RadioRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final T groupValue;
  final void Function(T) onChanged;
  const _RadioRow({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => onChanged(v as T),
              activeColor: TermexColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 13, color: TermexColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: TermexColors.textPrimary))),
          Switch(value: value, onChanged: onChanged, activeColor: TermexColors.primary),
        ],
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
