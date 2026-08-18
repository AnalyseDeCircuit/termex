import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../icons/termex_icons.dart';
import '../../../l10n/app_localizations.dart';

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

  /// True when the server has a network proxy attached (SOCKS5/HTTP/Tor).
  /// Rendered as a small purple "P" badge after the name.
  final bool hasProxy;

  /// True when the connection chain includes at least one SSH bastion
  /// hop. Rendered as a small blue "B" badge after the name.
  final bool hasBastion;

  /// True when the server was shared with a team workspace. Rendered
  /// as a green "T" badge so the user spots team-shared rows at a
  /// glance — mirrors the legacy Tauri tree affordance.
  final bool isShared;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// Fired on right-click (secondary tap) with the global position so
  /// the parent can anchor a context menu overlay. Long-press on
  /// trackpads / mobile maps to the same callback.
  final void Function(Offset globalPosition)? onContextMenu;

  /// Indentation depth — 8 px per level, matching macOS Finder sidebar
  /// where nesting is signalled by a small inset rather than a full
  /// chevron-width step.
  final int depth;

  /// Whether to reserve the chevron column on non-group rows.
  ///
  /// Servers have no chevron, so the space exists purely to line their icons
  /// up with the group rows above them. When the tree contains no groups at
  /// all there is nothing to align with, and the reserved column reads as a
  /// wide empty gutter down the left of every row — 32px of dead space before
  /// the icon on a flat list, counting the list's own padding.
  final bool reserveExpandSpace;

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
    this.hasProxy = false,
    this.hasBastion = false,
    this.isShared = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onContextMenu,
    this.depth = 0,
    this.reserveExpandSpace = true,
  });

  @override
  State<ServerTreeNode> createState() => _ServerTreeNodeState();
}

class _ServerTreeNodeState extends State<ServerTreeNode> {
  bool _hovered = false;

  Color _bgColor() {
    if (widget.isSelected) {
      return context.colors.primary.withOpacity(0.18);
    }
    if (_hovered) {
      return context.colors.backgroundTertiary.withOpacity(0.7);
    }
    return const Color(0x00000000);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final indent = widget.depth * 8.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        // Right-click / secondary-tap: parent opens a context menu
        // anchored to the global position. macOS sends this on both
        // right-click and Ctrl+click; on touch we fall back to a long
        // press surfaced through onLongPressStart.
        onSecondaryTapUp: widget.onContextMenu == null
            ? null
            : (d) => widget.onContextMenu!(d.globalPosition),
        onLongPressStart: widget.onContextMenu == null
            ? null
            : (d) => widget.onContextMenu!(d.globalPosition),
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
              // Expand/collapse chevron (groups), or the matching spacer on
              // server rows so their icons align under it. Dropped entirely
              // when the tree has no groups — see [reserveExpandSpace].
              if (widget.isGroup) ...[
                _ExpandIcon(isExpanded: widget.isExpanded),
                const SizedBox(width: TermexSpacing.xs),
              ] else if (widget.reserveExpandSpace) ...[
                // Matches `_ExpandIcon`'s 12px glyph. It was 16, which put
                // every server icon 4px to the right of the group icons it
                // was supposed to line up under.
                const SizedBox(width: 12),
                const SizedBox(width: TermexSpacing.xs),
              ],
              // Folder / server icon
              TermexIconWidget(
                widget.isGroup
                    ? (widget.isExpanded
                        ? TermexIcons.folderOpen
                        : TermexIcons.folder)
                    : TermexIcons.server,
                size: 14,
                color: widget.isGroup
                    ? context.colors.warning
                    : context.colors.neutral,
              ),
              const SizedBox(width: TermexSpacing.sm),
              // Name + optional subtitle
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.name,
                            style: TermexTypography.body.copyWith(
                              color: context.colors.textPrimary,
                              fontWeight: widget.isGroup
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Server-only routing badges. Order: proxy → bastion → shared.
                        if (widget.hasProxy) ...[
                          const SizedBox(width: 4),
                          _CapsuleBadge(
                            label: 'P',
                            color: const Color(0xFF8B5CF6), // purple
                            tooltip: l10n.serverBadgeProxyTooltip,
                          ),
                        ],
                        if (widget.hasBastion) ...[
                          const SizedBox(width: 3),
                          _CapsuleBadge(
                            label: 'B',
                            color: context.colors.primary,
                            tooltip: l10n.serverBadgeBastionTooltip,
                          ),
                        ],
                        if (widget.isShared) ...[
                          const SizedBox(width: 3),
                          _CapsuleBadge(
                            label: 'T',
                            color: context.colors.success,
                            tooltip: l10n.serverSharedToTeam,
                          ),
                        ],
                      ],
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: TermexTypography.caption.copyWith(
                          color: context.colors.textMuted,
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
                  _StatusDot(color: context.colors.success)
                else if (widget.lastConnected != null)
                  Text(
                    widget.lastConnected!,
                    style: TermexTypography.caption.copyWith(
                      color: context.colors.textMuted,
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
        color: context.colors.textSecondary,
      ),
    );
  }
}

/// Compact rounded-square badge used next to a server name to signal
/// routing / sharing properties (proxy / bastion / team-shared). The
/// glyph is a single uppercase character so the badge stays at 14×14
/// regardless of locale; the [`tooltip`] explains it on hover.
class _CapsuleBadge extends StatelessWidget {
  final String label;
  final Color color;
  final String tooltip;

  const _CapsuleBadge({
    required this.label,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 14,
        height: 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withOpacity(0.55), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            height: 1.0,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
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
