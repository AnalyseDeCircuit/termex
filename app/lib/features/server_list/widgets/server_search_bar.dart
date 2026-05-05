import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../icons/termex_icons.dart';

/// Full-width search input that sits at the top of the server sidebar.
/// Emits the filtered query with a 300 ms debounce.
class ServerSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const ServerSearchBar({super.key, required this.onChanged});

  @override
  State<ServerSearchBar> createState() => _ServerSearchBarState();
}

class _ServerSearchBarState extends State<ServerSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  void _handleChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(value);
    });
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        _focused ? TermexColors.borderFocus : TermexColors.border;
    final hasText = _controller.text.isNotEmpty;

    return SizedBox(
      height: 36,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: TermexColors.backgroundSecondary,
            borderRadius: TermexRadius.md,
            border: Border.all(
              color: borderColor,
              width: _focused ? 2.0 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
          child: Row(
            children: [
              TermexIconWidget(
                TermexIcons.search,
                size: 14,
                color: _focused
                    ? TermexColors.primary
                    : TermexColors.textSecondary,
              ),
              const SizedBox(width: TermexSpacing.sm),
              Expanded(
                child: EditableText(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textPrimary,
                  ),
                  cursorColor: TermexColors.primary,
                  backgroundCursorColor: TermexColors.backgroundTertiary,
                  selectionColor: TermexColors.primary.withOpacity(0.3),
                  onChanged: _handleChanged,
                ),
              ),
              if (hasText) ...[
                const SizedBox(width: TermexSpacing.xs),
                _ClearButton(onTap: _clear),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: _hovered
                ? TermexColors.backgroundTertiary
                : const Color(0x00000000),
            borderRadius: TermexRadius.full,
          ),
          alignment: Alignment.center,
          child: TermexIconWidget(
            TermexIcons.close,
            size: 11,
            color: TermexColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
