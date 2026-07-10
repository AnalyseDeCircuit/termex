/// Shared row layout used by every settings tab.
///
/// Layout adapts to viewport width:
///   - ≥ 600px (desktop / iPad): horizontal — 180px label column on the
///     left, Expanded control on the right.
///   - < 600px (iPhone / Android phone): vertical — label + hint on top,
///     control aligned right beneath it. Phones don't have enough
///     horizontal room to fit a 180px label *and* a comfortable
///     Dropdown / Switch in the same row without overflow stripes.
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
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final labelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(fontSize: 13, color: TermexColors.textPrimary),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: const TextStyle(
                fontSize: 11, color: TermexColors.textSecondary),
          ),
        ],
      ],
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            labelColumn,
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: labelColumn),
          Expanded(child: child),
        ],
      ),
    );
  }
}
