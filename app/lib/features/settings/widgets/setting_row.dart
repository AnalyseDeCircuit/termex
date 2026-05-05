/// Shared row layout used by every settings tab.
library;

import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

class SettingRow extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;

  const SettingRow({
    super.key,
    required this.label,
    this.hint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: TermexColors.textPrimary),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
