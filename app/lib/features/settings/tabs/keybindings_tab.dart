import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
import '../state/keybinding_provider.dart';
import '../widgets/conflict_warning.dart';
import '../widgets/keybinding_capture.dart';

class KeybindingsTab extends ConsumerWidget {
  const KeybindingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(keybindingProvider);
    final notifier = ref.read(keybindingProvider.notifier);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: notifier.resetAll,
                    icon: const Icon(Icons.restore, size: 14),
                    label: const Text('恢复默认', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: TermexColors.textSecondary,
                    ),
                  ),
                ],
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _HeaderText('命令')),
                    Expanded(flex: 2, child: _HeaderText('快捷键')),
                    Expanded(flex: 1, child: _HeaderText('上下文')),
                    const SizedBox(width: 36),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...state.bindings.map((b) => _KeybindingRow(
                    entry: b,
                    onCapture: (combo) => notifier.setBinding(b.action, combo),
                    onReset: () => notifier.resetAction(b.action),
                  )),
            ],
          ),
        ),
      ],
    );
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
        color: TermexColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _KeybindingRow extends StatelessWidget {
  final KeybindingEntry entry;
  final void Function(String) onCapture;
  final VoidCallback onReset;

  const _KeybindingRow({
    required this.entry,
    required this.onCapture,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              entry.action,
              style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: KeybindingCapture(
              currentValue: entry.keyCombination,
              onCaptured: onCapture,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              entry.context,
              style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
            ),
          ),
          GestureDetector(
            onTap: onReset,
            child: Icon(Icons.restore, size: 14, color: TermexColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
