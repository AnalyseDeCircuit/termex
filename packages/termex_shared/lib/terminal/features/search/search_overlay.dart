/// Terminal search overlay widget.
///
/// A toolbar pinned at the top-right of the terminal view. It drives a
/// [SearchController] and rebuilds only the parts that change (match counter,
/// toggle states) via [ListenableBuilder].
library;

import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter/services.dart';

import '../../../../design/colors.dart';
import '../../../../design/typography.dart';
import 'search_controller.dart';

export 'search_controller.dart';

/// A floating search bar that overlays the terminal.
///
/// Mount this inside a [Stack] positioned at the top-right corner.
/// The parent must provide a [SearchController] and the current list of
/// terminal lines so the overlay can trigger searches on every keystroke.
class SearchOverlay extends StatefulWidget {
  final SearchController controller;

  /// A callback that returns the current terminal lines on demand.
  /// Called every time the query or options change.
  final List<String> Function() getLines;

  const SearchOverlay({
    super.key,
    required this.controller,
    required this.getLines,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.controller.query;
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    widget.controller.setQuery(value, widget.getLines());
  }

  void _close() {
    widget.controller.close();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isOpen) return const SizedBox.shrink();
        return _SearchBar(
          textController: _textController,
          focusNode: _focusNode,
          controller: widget.controller,
          onQueryChanged: _onQueryChanged,
          onClose: _close,
          onNext: () => widget.controller.goNext(),
          onPrevious: () => widget.controller.goPrevious(),
          onToggleCase: () =>
              widget.controller.toggleCaseSensitive(widget.getLines()),
          onToggleWord: () =>
              widget.controller.toggleWholeWord(widget.getLines()),
          onToggleRegex: () =>
              widget.controller.toggleRegex(widget.getLines()),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final SearchController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleCase;
  final VoidCallback onToggleWord;
  final VoidCallback onToggleRegex;

  const _SearchBar({
    required this.textController,
    required this.focusNode,
    required this.controller,
    required this.onQueryChanged,
    required this.onClose,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleCase,
    required this.onToggleWord,
    required this.onToggleRegex,
  });

  @override
  Widget build(BuildContext context) {
    final opts = controller.options;
    final result = controller.result;
    final hasMatches = result.hasMatches;
    final matchLabel = controller.query.isEmpty
        ? ''
        : hasMatches
            ? '${result.currentIndex + 1} / ${result.count}'
            : '无结果';
    final labelColor = controller.query.isNotEmpty && !hasMatches
        ? TermexColors.danger
        : TermexColors.textSecondary;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            onClose();
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              onPrevious();
            } else {
              onNext();
            }
          }
        }
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: TermexColors.backgroundSecondary,
          border: Border.all(color: TermexColors.border),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            // Search icon
            const Icon(
              Icons.search,
              size: 16,
              color: TermexColors.textSecondary,
            ),
            const SizedBox(width: 6),
            // Text input
            SizedBox(
              width: 200,
              child: TextField(
                controller: textController,
                focusNode: focusNode,
                autofocus: true,
                style: TermexTypography.monospace.copyWith(
                  fontSize: 13,
                  color: TermexColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  border: InputBorder.none,
                  hintText: '搜索…',
                  hintStyle: TextStyle(color: TermexColors.textMuted),
                ),
                onChanged: onQueryChanged,
              ),
            ),
            // Match counter
            if (matchLabel.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                matchLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: labelColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const SizedBox(width: 6),
            _Divider(),
            // Toggle: case-sensitive
            _ToggleButton(
              tooltip: '区分大小写 (Alt+C)',
              active: opts.caseSensitive,
              onTap: onToggleCase,
              child: const Text('Aa',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            // Toggle: whole word
            _ToggleButton(
              tooltip: '全词匹配 (Alt+W)',
              active: opts.wholeWord,
              onTap: onToggleWord,
              child: const Text('.Aa',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5)),
            ),
            // Toggle: regex
            _ToggleButton(
              tooltip: '正则表达式 (Alt+R)',
              active: opts.useRegex,
              onTap: onToggleRegex,
              child: const Text('.*',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            _Divider(),
            // Previous match
            _IconBtn(
              tooltip: '上一个 (Shift+Enter)',
              icon: Icons.keyboard_arrow_up,
              enabled: hasMatches,
              onTap: onPrevious,
            ),
            // Next match
            _IconBtn(
              tooltip: '下一个 (Enter)',
              icon: Icons.keyboard_arrow_down,
              enabled: hasMatches,
              onTap: onNext,
            ),
            _Divider(),
            // Close
            _IconBtn(
              tooltip: '关闭 (Esc)',
              icon: Icons.close,
              enabled: true,
              onTap: onClose,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 20,
        color: TermexColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

class _ToggleButton extends StatelessWidget {
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  final Widget child;

  const _ToggleButton({
    required this.tooltip,
    required this.active,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active
                ? TermexColors.primary.withOpacity(0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: active
                ? Border.all(color: TermexColors.primary.withOpacity(0.6))
                : null,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: active ? TermexColors.primary : TermexColors.textSecondary,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _IconBtn({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? TermexColors.textSecondary : TermexColors.textMuted,
          ),
        ),
      ),
    );
  }
}
