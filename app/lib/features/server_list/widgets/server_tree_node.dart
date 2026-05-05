import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../icons/termex_icons.dart';

/// A single visual row in the server tree.
/// Represents either a group (collapsible) or a server entry.
class ServerTreeNode extends StatefulWidget {
  final bool isGroup;
  final String id;
  final String name;

  /// host:port for servers
  final String? subtitle;

  /// Relative time string, e.g. "2 hours ago"
  final String? lastConnected;

  /// Whether a group node is expanded
  final bool isExpanded;

  final bool isSelected;

  /// For servers — shows a green status dot when true
  final bool isConnected;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// Indentation depth (each level = 16 px)
  final int depth;

  const ServerTreeNode({
    super.key,
    required this.isGroup,
    required this.id,
    required this.name,
    this.subtitle,
    this.lastConnected,
    required this.isExpanded,
    required this.isSelected,
    this.isConnected = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.depth = 0,
  });

  @override
  State<ServerTreeNode> createState() => _ServerTreeNodeState();
}

class _ServerTreeNodeState extends State<ServerTreeNode> {
  bool _hovered = false;

  Color _bgColor() {
    if (widget.isSelected) {
      return TermexColors.primary.withOpacity(0.18);
    }
    if (_hovered) {
      return TermexColors.backgroundTertiary.withOpacity(0.7);
    }
    return const Color(0x00000000);
  }

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 16.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          height: 40,
          padding: EdgeInsets.only(
            left: TermexSpacing.sm + indent,
            right: TermexSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _bgColor(),
            borderRadius: TermexRadius.sm,
          ),
          child: Row(
            children: [
              // Expand/collapse chevron (groups) or spacer (servers)
              if (widget.isGroup)
                _ExpandIcon(isExpanded: widget.isExpanded)
              else
                const SizedBox(width: 16),
              const SizedBox(width: TermexSpacing.xs),
              // Folder / server icon
              TermexIconWidget(
                widget.isGroup
                    ? (widget.isExpanded
                        ? TermexIcons.folderOpen
                        : TermexIcons.folder)
                    : TermexIcons.server,
                size: 14,
                color: widget.isGroup
                    ? TermexColors.warning
                    : TermexColors.neutral,
              ),
              const SizedBox(width: TermexSpacing.sm),
              // Name + optional subtitle
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TermexTypography.body.copyWith(
                        color: widget.isSelected
                            ? TermexColors.textPrimary
                            : TermexColors.textPrimary,
                        fontWeight: widget.isGroup
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: TermexTypography.caption.copyWith(
                          color: TermexColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Right side: connected dot or last-connected time
              if (!widget.isGroup) ...[
                const SizedBox(width: TermexSpacing.xs),
                if (widget.isConnected)
                  _StatusDot(color: TermexColors.success)
                else if (widget.lastConnected != null)
                  Text(
                    widget.lastConnected!,
                    style: TermexTypography.caption.copyWith(
                      color: TermexColors.textMuted,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandIcon extends StatelessWidget {
  final bool isExpanded;
  const _ExpandIcon({required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isExpanded ? 0.25 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: TermexIconWidget(
        TermexIcons.chevronRight,
        size: 12,
        color: TermexColors.textSecondary,
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        borderRadius: TermexRadius.full,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
