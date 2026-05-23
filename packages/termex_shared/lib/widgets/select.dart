import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../design/radius.dart';
import '../design/spacing.dart';
import '../design/elevation.dart';

@immutable
class SelectOption<T> {
  final T value;
  final String label;
  final bool disabled;

  const SelectOption({
    required this.value,
    required this.label,
    this.disabled = false,
  });
}

class TermexSelect<T> extends StatefulWidget {
  final List<SelectOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? placeholder;
  final bool disabled;
  final bool searchable;

  const TermexSelect({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    this.placeholder,
    this.disabled = false,
    this.searchable = false,
  });

  @override
  State<TermexSelect<T>> createState() => _TermexSelectState<T>();
}

class _TermexSelectState<T> extends State<TermexSelect<T>> {
  bool _open = false;
  bool _hovered = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  SelectOption<T>? get _selected {
    if (widget.value == null) return null;
    try {
      return widget.options.firstWhere((o) => o.value == widget.value);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _closeDropdown();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openDropdown() {
    if (widget.disabled || _open) return;
    setState(() => _open = true);
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeDropdown() {
    if (!_open) return;
    if (mounted) {
      setState(() {
        _open = false;
        _searchQuery = '';
      });
    } else {
      _open = false;
      _searchQuery = '';
    }
    _searchController.clear();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _select(T value) {
    _closeDropdown();
    widget.onChanged?.call(value);
  }

  List<SelectOption<T>> get _filtered {
    if (_searchQuery.isEmpty) return widget.options;
    final q = _searchQuery.toLowerCase();
    return widget.options.where((o) => o.label.toLowerCase().contains(q)).toList();
  }

  OverlayEntry _buildOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (ctx) => _DropdownOverlay<T>(
        layerLink: _layerLink,
        triggerWidth: size.width,
        options: _filtered,
        selectedValue: widget.value,
        showSearch: widget.searchable && widget.options.length > 10,
        searchController: _searchController,
        onQueryChanged: (q) {
          _searchQuery = q;
          _overlayEntry?.markNeedsBuild();
        },
        onSelect: _select,
        onDismiss: _closeDropdown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final borderColor =
        _open ? TermexColors.borderFocus : TermexColors.border;
    final borderWidth = _open ? 2.0 : 1.0;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Opacity(
        opacity: widget.disabled ? 0.5 : 1.0,
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              _open ? _closeDropdown() : _openDropdown();
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              _closeDropdown();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor: widget.disabled
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: _open ? _closeDropdown : _openDropdown,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 36,
                padding: const EdgeInsets.symmetric(
                    horizontal: TermexSpacing.md),
                decoration: BoxDecoration(
                  color: _hovered && !widget.disabled
                      ? TermexColors.backgroundTertiary
                      : TermexColors.backgroundSecondary,
                  borderRadius: TermexRadius.md,
                  border:
                      Border.all(color: borderColor, width: borderWidth),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected?.label ??
                            widget.placeholder ??
                            '',
                        style: TermexTypography.body.copyWith(
                          color: selected == null
                              ? TermexColors.textMuted
                              : TermexColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: TermexSpacing.sm),
                    _ChevronIcon(open: _open),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChevronIcon extends StatelessWidget {
  final bool open;
  const _ChevronIcon({required this.open});

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: open ? 0.5 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: CustomPaint(
        size: const Size(12, 8),
        painter: _ChevronPainter(),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TermexColors.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}

class _DropdownOverlay<T> extends StatefulWidget {
  final LayerLink layerLink;
  final double triggerWidth;
  final List<SelectOption<T>> options;
  final T? selectedValue;
  final bool showSearch;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<T> onSelect;
  final VoidCallback onDismiss;

  const _DropdownOverlay({
    required this.layerLink,
    required this.triggerWidth,
    required this.options,
    required this.selectedValue,
    required this.showSearch,
    required this.searchController,
    required this.onQueryChanged,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_DropdownOverlay<T>> createState() => _DropdownOverlayState<T>();
}

class _DropdownOverlayState<T> extends State<_DropdownOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Align(
            alignment: Alignment.topLeft,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: widget.triggerWidth,
                  maxWidth: widget.triggerWidth < 200
                      ? 200
                      : widget.triggerWidth,
                  maxHeight: 240,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: TermexColors.backgroundSecondary,
                    borderRadius: TermexRadius.md,
                    border: Border.all(color: TermexColors.border),
                    boxShadow: TermexElevation.e2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showSearch)
                        _SearchField(
                          controller: widget.searchController,
                          onChanged: (q) {
                            widget.onQueryChanged(q);
                            setState(() {});
                          },
                        ),
                      Flexible(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              vertical: TermexSpacing.xs),
                          shrinkWrap: true,
                          itemCount: widget.options.length,
                          itemBuilder: (ctx, i) {
                            final opt = widget.options[i];
                            final isSelected = opt.value == widget.selectedValue;
                            return _OptionTile<T>(
                              option: opt,
                              isSelected: isSelected,
                              onTap: opt.disabled
                                  ? null
                                  : () => widget.onSelect(opt.value),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final focusNode = FocusNode();
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TermexColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
      child: EditableText(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        style: TermexTypography.body.copyWith(color: TermexColors.textPrimary),
        cursorColor: TermexColors.primary,
        backgroundCursorColor: TermexColors.backgroundTertiary,
        selectionColor: TermexColors.primary.withOpacity(0.3),
        onChanged: onChanged,
      ),
    );
  }
}

class _OptionTile<T> extends StatefulWidget {
  final SelectOption<T> option;
  final bool isSelected;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_OptionTile<T>> createState() => _OptionTileState<T>();
}

class _OptionTileState<T> extends State<_OptionTile<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0x00000000);
    if (_hovered && widget.onTap != null) bg = TermexColors.backgroundTertiary;
    if (widget.isSelected) {
      bg = TermexColors.primary.withOpacity(0.15);
    }

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: widget.option.disabled ? 0.4 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 36,
            padding: const EdgeInsets.symmetric(
                horizontal: TermexSpacing.md),
            color: bg,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.option.label,
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isSelected)
                  const _CheckIcon(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckIcon extends StatelessWidget {
  const _CheckIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 14),
      painter: _CheckPainter(),
    );
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TermexColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.5)
      ..lineTo(size.width * 0.42, size.height * 0.75)
      ..lineTo(size.width * 0.85, size.height * 0.2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}
