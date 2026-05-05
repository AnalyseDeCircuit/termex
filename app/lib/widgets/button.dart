import 'package:flutter/material.dart' hide ButtonBar;
import 'package:flutter/services.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../design/radius.dart';

enum ButtonVariant { primary, secondary, ghost, danger }

enum ButtonSize { small, medium, large }

enum IconPosition { start, end }

double _buttonHeight(ButtonSize size) => switch (size) {
      ButtonSize.small => 28,
      ButtonSize.medium => 36,
      ButtonSize.large => 44,
    };

double _hPadding(ButtonSize size) => switch (size) {
      ButtonSize.small => 12,
      ButtonSize.medium => 16,
      ButtonSize.large => 20,
    };

double _fontSize(ButtonSize size) => switch (size) {
      ButtonSize.small => 12,
      ButtonSize.medium => 14,
      ButtonSize.large => 15,
    };

Color _bgColor(ButtonVariant variant) => switch (variant) {
      ButtonVariant.primary => TermexColors.primary,
      ButtonVariant.secondary => TermexColors.backgroundTertiary,
      ButtonVariant.ghost => const Color(0x00000000),
      ButtonVariant.danger => TermexColors.danger,
    };

Color _textColor(ButtonVariant variant) => switch (variant) {
      ButtonVariant.primary => const Color(0xFFFFFFFF),
      ButtonVariant.secondary => TermexColors.textPrimary,
      ButtonVariant.ghost => TermexColors.textPrimary,
      ButtonVariant.danger => const Color(0xFFFFFFFF),
    };

class TermexButton extends StatefulWidget {
  final String label;
  final ButtonVariant variant;
  final ButtonSize size;
  final Widget? icon;
  final IconPosition iconPosition;
  final bool disabled;
  final bool loading;
  final VoidCallback? onPressed;

  const TermexButton({
    super.key,
    required this.label,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.iconPosition = IconPosition.start,
    this.disabled = false,
    this.loading = false,
    this.onPressed,
  });

  @override
  State<TermexButton> createState() => _TermexButtonState();
}

class _TermexButtonState extends State<TermexButton> {
  bool _hovered = false;
  bool _focused = false;

  bool get _isInteractive => !widget.disabled && !widget.loading;

  void _handleTap() {
    if (_isInteractive) widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor(widget.variant);
    final fg = _textColor(widget.variant);
    final height = _buttonHeight(widget.size);
    final hPad = _hPadding(widget.size);
    final fs = _fontSize(widget.size);
    final isGhost = widget.variant == ButtonVariant.ghost;

    Border? border;
    if (isGhost) {
      border = Border.all(color: TermexColors.border, width: 1);
    }
    if (_focused) {
      border = Border.all(color: TermexColors.borderFocus, width: 2);
    }

    Color effectiveBg = bg;
    if (_hovered && _isInteractive) {
      effectiveBg = Color.alphaBlend(const Color(0x14FFFFFF), bg);
    }

    Widget content;
    if (widget.loading) {
      content = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else {
      final label = Text(
        widget.label,
        style: TermexTypography.body.copyWith(
          color: fg,
          fontSize: fs,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      );
      if (widget.icon != null) {
        final children = widget.iconPosition == IconPosition.start
            ? [widget.icon!, const SizedBox(width: 6), label]
            : [label, const SizedBox(width: 6), widget.icon!];
        content = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        );
      } else {
        content = label;
      }
    }

    return Semantics(
      button: true,
      enabled: _isInteractive,
      child: Opacity(
        opacity: widget.disabled ? 0.4 : 1.0,
        child: Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          onKeyEvent: (node, event) {
            if (!_isInteractive) return KeyEventResult.ignored;
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              _handleTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor: _isInteractive
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: _handleTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                height: height,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                decoration: BoxDecoration(
                  color: effectiveBg,
                  borderRadius: TermexRadius.md,
                  border: border,
                ),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TermexIconButton extends StatefulWidget {
  final Widget icon;
  final ButtonSize size;
  final ButtonVariant variant;
  final bool disabled;
  final String? tooltip;
  final VoidCallback? onPressed;

  const TermexIconButton({
    super.key,
    required this.icon,
    this.size = ButtonSize.medium,
    this.variant = ButtonVariant.ghost,
    this.disabled = false,
    this.tooltip,
    this.onPressed,
  });

  @override
  State<TermexIconButton> createState() => _TermexIconButtonState();
}

class _TermexIconButtonState extends State<TermexIconButton> {
  bool _hovered = false;
  bool _focused = false;

  double get _dimension => switch (widget.size) {
        ButtonSize.small => 28,
        ButtonSize.medium => 32,
        ButtonSize.large => 36,
      };

  bool get _isInteractive => !widget.disabled;

  void _handleTap() {
    if (_isInteractive) widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor(widget.variant);
    Color effectiveBg = bg;
    if (_hovered && _isInteractive) {
      effectiveBg = Color.alphaBlend(const Color(0x14FFFFFF), bg);
    }

    Border? border;
    final isGhost = widget.variant == ButtonVariant.ghost;
    if (isGhost) {
      border = Border.all(color: TermexColors.border, width: 1);
    }
    if (_focused) {
      border = Border.all(color: TermexColors.borderFocus, width: 2);
    }

    return Semantics(
      button: true,
      enabled: _isInteractive,
      label: widget.tooltip,
      child: Opacity(
        opacity: widget.disabled ? 0.4 : 1.0,
        child: Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          onKeyEvent: (node, event) {
            if (!_isInteractive) return KeyEventResult.ignored;
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              _handleTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor: _isInteractive
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: _handleTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: _dimension,
                height: _dimension,
                decoration: BoxDecoration(
                  color: effectiveBg,
                  borderRadius: TermexRadius.md,
                  border: border,
                ),
                alignment: Alignment.center,
                child: widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
