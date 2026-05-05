import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../design/radius.dart';
import '../design/spacing.dart';
import 'form_validators.dart';

class TermexTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final Widget? leadingIcon;
  final Widget? trailing;
  final bool obscureText;
  final bool autofocus;
  final bool readOnly;
  final int? maxLines;
  final List<Validator<String>>? validators;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final TextInputType? keyboardType;
  final bool disabled;

  const TermexTextField({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.leadingIcon,
    this.trailing,
    this.obscureText = false,
    this.autofocus = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.validators,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.disabled = false,
  });

  @override
  State<TermexTextField> createState() => _TermexTextFieldState();
}

class _TermexTextFieldState extends State<TermexTextField> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;
  bool _ownsController = false;
  bool _focused = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    if (widget.controller == null) {
      _controller = TextEditingController();
      _ownsController = true;
    } else {
      _controller = widget.controller!;
    }
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  String? _validate(String value) {
    if (widget.validators == null) return null;
    for (final v in widget.validators!) {
      final err = v(value);
      if (err != null) return err;
    }
    return null;
  }

  void _handleChanged(String value) {
    if (widget.validators != null) {
      setState(() => _validationError = _validate(value));
    }
    widget.onChanged?.call(value);
  }

  void _handleSubmitted(String value) {
    if (widget.validators != null) {
      setState(() => _validationError = _validate(value));
    }
    widget.onSubmitted?.call();
  }

  String? get _effectiveError => widget.errorText ?? _validationError;

  bool get _hasError => _effectiveError != null;

  @override
  Widget build(BuildContext context) {
    final borderColor = _hasError
        ? TermexColors.danger
        : _focused
            ? TermexColors.borderFocus
            : TermexColors.border;
    final borderWidth = _focused ? 2.0 : 1.0;
    final isMultiline = (widget.maxLines ?? 1) != 1;

    return Opacity(
      opacity: widget.disabled ? 0.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: TermexTypography.bodySmall.copyWith(
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(height: TermexSpacing.xs),
          ],
          GestureDetector(
            onTap: widget.disabled ? null : () => _focusNode.requestFocus(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              constraints: BoxConstraints(
                minHeight: isMultiline ? 80 : 36,
              ),
              decoration: BoxDecoration(
                color: TermexColors.backgroundSecondary,
                borderRadius: TermexRadius.md,
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: TermexSpacing.md,
                vertical: isMultiline ? TermexSpacing.sm : 0,
              ),
              child: Row(
                crossAxisAlignment: isMultiline
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  if (widget.leadingIcon != null) ...[
                    widget.leadingIcon!,
                    const SizedBox(width: TermexSpacing.sm),
                  ],
                  Expanded(
                    child: Stack(
                      alignment: isMultiline
                          ? Alignment.topLeft
                          : Alignment.centerLeft,
                      children: [
                        if (widget.placeholder != null &&
                            _controller.text.isEmpty)
                          Text(
                            widget.placeholder!,
                            style: TermexTypography.body.copyWith(
                              color: TermexColors.textSecondary,
                            ),
                          ),
                        EditableText(
                          controller: _controller,
                          focusNode: _focusNode,
                          readOnly: widget.readOnly || widget.disabled,
                          obscureText: widget.obscureText,
                          maxLines: widget.obscureText ? 1 : widget.maxLines,
                          minLines: 1,
                          keyboardType: widget.keyboardType,
                          style: TermexTypography.body.copyWith(
                            color: TermexColors.textPrimary,
                          ),
                          cursorColor: TermexColors.primary,
                          backgroundCursorColor: TermexColors.backgroundTertiary,
                          selectionColor:
                              TermexColors.primary.withOpacity(0.3),
                          onChanged: _handleChanged,
                          onSubmitted: _handleSubmitted,
                          strutStyle: const StrutStyle(forceStrutHeight: true),
                        ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: TermexSpacing.sm),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
          if (_hasError) ...[
            const SizedBox(height: TermexSpacing.xs),
            Text(
              _effectiveError!,
              style: TermexTypography.caption.copyWith(
                color: TermexColors.danger,
              ),
            ),
          ] else if (widget.helperText != null) ...[
            const SizedBox(height: TermexSpacing.xs),
            Text(
              widget.helperText!,
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
