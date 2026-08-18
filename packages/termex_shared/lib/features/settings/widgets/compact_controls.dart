/// Compact form controls used by every settings tab.
///
/// The default Material `Switch` and `DropdownButton` look oversized inside
/// our settings dialog (which is denser than Material's default density).
/// These wrappers tune visual density + scale so toggles, dropdowns and
/// segment chips share a consistent, compact rhythm across all tabs.
library;

import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// A 75%-scaled Material Switch that keeps full hit-testing semantics but
/// reads as a sidebar-class control rather than a hero CTA.
class CompactSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const CompactSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      alignment: Alignment.centerRight,
      scale: 0.75,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: context.colors.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// `DropdownButton` wrapped to enforce compact dimensions: shorter row
/// height in the popup, denser text, and the standard Termex typography.
class CompactDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double width;

  const CompactDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 140,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 28,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          itemHeight: kMinInteractiveDimension, // Material minimum.
          icon: Icon(Icons.expand_more,
              size: 14, color: context.colors.textMuted),
          dropdownColor: context.colors.backgroundSecondary,
          style: TextStyle(
            fontSize: 12,
            color: context.colors.textPrimary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Helper to wrap a `Text(...)` with smaller-than-default size for use as a
/// `DropdownMenuItem.child`, so popup rows look 12pt instead of 14pt.
DropdownMenuItem<T> compactDropdownItem<T>(T value, String label) =>
    DropdownMenuItem<T>(
      value: value,
      child: Builder(
        builder: (context) => Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
        ),
      ),
    );
