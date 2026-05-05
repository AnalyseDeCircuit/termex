import 'package:flutter/material.dart';
import '../../../design/tokens.dart';

/// Banner shown when a keybinding conflicts with an existing one.
class ConflictWarning extends StatelessWidget {
  final String conflictingAction;
  final VoidCallback onDismiss;

  const ConflictWarning({
    super.key,
    required this.conflictingAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TermexColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TermexColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: TermexColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '与「$conflictingAction」快捷键冲突，已取消保存',
              style: TextStyle(fontSize: 12, color: TermexColors.warning),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 13, color: TermexColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
