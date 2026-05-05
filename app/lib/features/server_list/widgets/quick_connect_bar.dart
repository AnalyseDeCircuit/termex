import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../design/elevation.dart';
import '../../../icons/termex_icons.dart';
import '../../../widgets/button.dart';
import '../state/quick_connect_provider.dart';

/// Top-bar quick-connect input.
///
/// Parses `user@host:port` input and calls [onConnect] when the user
/// confirms the connection.  Shows a recent-history dropdown on focus.
class QuickConnectBar extends ConsumerStatefulWidget {
  final void Function(String host, int port, String username)? onConnect;

  const QuickConnectBar({super.key, this.onConnect});

  @override
  ConsumerState<QuickConnectBar> createState() => _QuickConnectBarState();
}

class _QuickConnectBarState extends ConsumerState<QuickConnectBar> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _showDropdown = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // Parsed preview
  String _parsedHost = '';
  int _parsedPort = 22;
  String _parsedUsername = '';
  bool _hasValidInput = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _closeDropdown();
    _ctrl.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      _openDropdown();
    } else {
      _closeDropdown();
    }
  }

  void _openDropdown() {
    final history =
        ref.read(quickConnectHistoryProvider).valueOrNull ?? const [];
    if (history.isEmpty) return;
    if (_showDropdown) return;
    setState(() => _showDropdown = true);
    _overlayEntry = _buildOverlay(history);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeDropdown() {
    if (!_showDropdown) return;
    setState(() => _showDropdown = false);
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleChanged(String value) {
    if (value.trim().isEmpty) {
      setState(() => _hasValidInput = false);
      return;
    }
    final parsed = QuickConnectParser.parse(value);
    setState(() {
      _parsedHost = parsed.host;
      _parsedPort = parsed.port;
      _parsedUsername = parsed.username;
      _hasValidInput = parsed.host.isNotEmpty;
    });
    // Refresh dropdown
    if (_showDropdown) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _connect() {
    if (!_hasValidInput) return;
    _closeDropdown();
    ref
        .read(quickConnectHistoryProvider.notifier)
        .add(_parsedHost, _parsedPort, _parsedUsername);
    widget.onConnect?.call(_parsedHost, _parsedPort, _parsedUsername);
    _ctrl.clear();
    _focusNode.unfocus();
    setState(() => _hasValidInput = false);
  }

  void _connectFromHistory(QuickConnectEntry entry) {
    _closeDropdown();
    _ctrl.text = '${entry.username}@${entry.host}:${entry.port}';
    widget.onConnect?.call(entry.host, entry.port, entry.username);
  }

  OverlayEntry _buildOverlay(List<QuickConnectEntry> history) {
    final renderBox = context.findRenderObject() as RenderBox;
    final width = renderBox.size.width;

    return OverlayEntry(
      builder: (ctx) {
        final currentHistory =
            ref.read(quickConnectHistoryProvider).valueOrNull ?? const [];
        return _HistoryDropdown(
          layerLink: _layerLink,
          width: width,
          history: currentHistory,
          onSelect: _connectFromHistory,
          onDismiss: _closeDropdown,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        _focused ? TermexColors.borderFocus : TermexColors.border;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Input row ----
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
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
                  TermexIcons.connect,
                  size: 14,
                  color: _focused
                      ? TermexColors.primary
                      : TermexColors.textSecondary,
                ),
                const SizedBox(width: TermexSpacing.sm),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter) {
                        _connect();
                        return KeyEventResult.handled;
                      }
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        _closeDropdown();
                        _focusNode.unfocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: EditableText(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      style: TermexTypography.monospace.copyWith(
                        fontSize: 13,
                        color: TermexColors.textPrimary,
                      ),
                      cursorColor: TermexColors.primary,
                      backgroundCursorColor: TermexColors.backgroundTertiary,
                      selectionColor: TermexColors.primary.withOpacity(0.3),
                      onChanged: _handleChanged,
                      onSubmitted: (_) => _connect(),
                    ),
                  ),
                ),
                if (_hasValidInput) ...[
                  const SizedBox(width: TermexSpacing.sm),
                  TermexButton(
                    label: 'Connect',
                    size: ButtonSize.small,
                    onPressed: _connect,
                  ),
                ] else ...[
                  const SizedBox(width: TermexSpacing.sm),
                  Text(
                    'user@host:port',
                    style: TermexTypography.caption.copyWith(
                      color: TermexColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ---- Parsed preview ----
          if (_hasValidInput && _focused) ...[
            const SizedBox(height: TermexSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.xs),
              child: Row(
                children: [
                  _PreviewChip(label: _parsedHost, icon: TermexIcons.server),
                  const SizedBox(width: TermexSpacing.xs),
                  _PreviewChip(
                      label: 'port $_parsedPort', icon: TermexIcons.link),
                  if (_parsedUsername.isNotEmpty) ...[
                    const SizedBox(width: TermexSpacing.xs),
                    _PreviewChip(
                        label: _parsedUsername, icon: TermexIcons.user),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview chip
// ---------------------------------------------------------------------------

class _PreviewChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PreviewChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: TermexColors.backgroundTertiary,
        borderRadius: TermexRadius.full,
        border: Border.all(color: TermexColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TermexIconWidget(icon, size: 10, color: TermexColors.textSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: TermexTypography.caption.copyWith(
              color: TermexColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History dropdown overlay
// ---------------------------------------------------------------------------

class _HistoryDropdown extends StatefulWidget {
  final LayerLink layerLink;
  final double width;
  final List<QuickConnectEntry> history;
  final void Function(QuickConnectEntry) onSelect;
  final VoidCallback onDismiss;

  const _HistoryDropdown({
    required this.layerLink,
    required this.width,
    required this.history,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_HistoryDropdown> createState() => _HistoryDropdownState();
}

class _HistoryDropdownState extends State<_HistoryDropdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 42),
          child: Align(
            alignment: Alignment.topLeft,
            child: FadeTransition(
              opacity: _fade,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: widget.width,
                  maxWidth: widget.width,
                  maxHeight: 220,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TermexSpacing.md,
                          vertical: TermexSpacing.sm,
                        ),
                        child: Text(
                          'Recent',
                          style: TermexTypography.caption.copyWith(
                            color: TermexColors.textMuted,
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(
                              bottom: TermexSpacing.xs),
                          itemCount: widget.history.length,
                          itemBuilder: (ctx, i) {
                            final e = widget.history[i];
                            return _HistoryTile(
                              entry: e,
                              onTap: () => widget.onSelect(e),
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

class _HistoryTile extends StatefulWidget {
  final QuickConnectEntry entry;
  final VoidCallback onTap;
  const _HistoryTile({required this.entry, required this.onTap});

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
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
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
          color: _hovered
              ? TermexColors.backgroundTertiary
              : const Color(0x00000000),
          child: Row(
            children: [
              TermexIconWidget(
                TermexIcons.server,
                size: 13,
                color: TermexColors.textSecondary,
              ),
              const SizedBox(width: TermexSpacing.sm),
              Expanded(
                child: Text(
                  '${widget.entry.username}@${widget.entry.host}:${widget.entry.port}',
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textPrimary,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
