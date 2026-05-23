/// Autocomplete suggestion dropdown overlay for the terminal.
///
/// Renders a floating list of [AutocompleteSuggestion]s below the cursor.
/// The parent terminal view owns the [AutocompleteController] and calls
/// [onAccepted] with the text to insert when the user confirms a suggestion.
library;

import 'package:flutter/material.dart';

import '../../../../design/colors.dart';
import '../../../../design/typography.dart';
import 'autocomplete_engine.dart';

export 'autocomplete_engine.dart';

/// Floating dropdown list of autocomplete suggestions.
///
/// Place inside a [Stack] at the cursor's pixel position. The widget
/// is invisible when [controller.isOpen] is false.
class AutocompleteOverlay extends StatelessWidget {
  final AutocompleteController controller;

  /// Called with the text suffix to append to the input line.
  final ValueChanged<String> onAccepted;

  /// Current input line — needed to compute the suffix on accept.
  final String inputLine;

  const AutocompleteOverlay({
    super.key,
    required this.controller,
    required this.onAccepted,
    required this.inputLine,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isOpen) return const SizedBox.shrink();
        return _SuggestionList(
          suggestions: controller.suggestions,
          selectedIndex: controller.selectedIndex,
          onTap: (idx) {
            final sug = controller.suggestions[idx];
            controller.close();
            final prefix = _lastToken(inputLine);
            final suffix = sug.value.startsWith(prefix)
                ? sug.value.substring(prefix.length)
                : sug.value;
            onAccepted(suffix);
          },
        );
      },
    );
  }

  static String _lastToken(String line) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) return '';
    final idx = trimmed.lastIndexOf(' ');
    return idx == -1 ? trimmed : trimmed.substring(idx + 1);
  }
}

class _SuggestionList extends StatelessWidget {
  final List<AutocompleteSuggestion> suggestions;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _SuggestionList({
    required this.suggestions,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360, maxHeight: 220),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: TermexColors.backgroundSecondary,
            border: Border.all(color: TermexColors.border),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x50000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, i) {
              final s = suggestions[i];
              final isSelected = i == selectedIndex;
              return _SuggestionRow(
                suggestion: s,
                isSelected: isSelected,
                onTap: () => onTap(i),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final AutocompleteSuggestion suggestion;
  final bool isSelected;
  final VoidCallback onTap;

  const _SuggestionRow({
    required this.suggestion,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: isSelected
            ? TermexColors.primary.withOpacity(0.2)
            : Colors.transparent,
        child: Row(
          children: [
            _KindIcon(kind: suggestion.kind),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                suggestion.value,
                style: TermexTypography.monospace.copyWith(
                  fontSize: 13,
                  color: isSelected
                      ? TermexColors.textPrimary
                      : TermexColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (suggestion.description != null)
              Flexible(
                flex: 0,
                child: Text(
                  suggestion.description!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: TermexColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  final SuggestionKind kind;

  const _KindIcon({required this.kind});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      SuggestionKind.command => (Icons.terminal, TermexColors.primary),
      SuggestionKind.flag => (Icons.flag_outlined, TermexColors.warning),
      SuggestionKind.path => (Icons.folder_outlined, TermexColors.neutral),
      SuggestionKind.variable => (Icons.data_object, TermexColors.success),
      SuggestionKind.history => (Icons.history, TermexColors.textMuted),
    };
    return Icon(icon, size: 14, color: color);
  }
}
