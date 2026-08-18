import 'package:flutter/widgets.dart';

import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/spacing.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/design/radius.dart';
import 'package:termex_shared/icons/termex_icons.dart';

/// Commands surfaced by the sidebar's "Termex ▾" dropdown — mirrors
/// `src/components/sidebar/SidebarMenu.vue`.
enum SidebarTermexCommand {
  newConnection,
  newGroup,
  importConfig,
  exportConfig,
  importSshConfig,
  settings,
}

/// Popup menu shown anchored to the "Termex" pill in the sidebar header.
///
/// Layout matches Tauri's `el-dropdown` menu order:
///   ➕ 新建连接
///   📁 新建分组
///   ──────────────
///   ⬆ 导入配置
///   ⬇ 导出配置
///   ⬆ 导入 SSH 配置
///   ──────────────
///   ⚙ 设置
class SidebarTermexMenu extends StatelessWidget {
  final LayerLink layerLink;
  final void Function(SidebarTermexCommand) onCommand;
  final VoidCallback onDismiss;

  const SidebarTermexMenu({
    super.key,
    required this.layerLink,
    required this.onCommand,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Translucent overlay swallows clicks and dismisses the menu.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: _MenuCard(
            children: [
              _MenuItem(
                icon: TermexIcons.add,
                label: '新建连接',
                onTap: () => onCommand(SidebarTermexCommand.newConnection),
              ),
              _MenuItem(
                icon: TermexIcons.folder,
                label: '新建分组',
                onTap: () => onCommand(SidebarTermexCommand.newGroup),
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: TermexIcons.upload,
                label: '导入配置',
                onTap: () => onCommand(SidebarTermexCommand.importConfig),
              ),
              _MenuItem(
                icon: TermexIcons.download,
                label: '导出配置',
                onTap: () => onCommand(SidebarTermexCommand.exportConfig),
              ),
              _MenuItem(
                icon: TermexIcons.upload,
                label: '导入 SSH 配置',
                onTap: () => onCommand(SidebarTermexCommand.importSshConfig),
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: TermexIcons.settings,
                label: '设置',
                onTap: () => onCommand(SidebarTermexCommand.settings),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(vertical: TermexSpacing.xs),
      decoration: BoxDecoration(
        color: context.colors.backgroundPrimary,
        borderRadius: TermexRadius.md,
        border: Border.all(color: context.colors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
          color: _hovered
              ? context.colors.backgroundTertiary
              : const Color(0x00000000),
          child: Row(
            children: [
              TermexIconWidget(
                widget.icon,
                size: 13,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: TermexSpacing.sm),
              Text(
                widget.label,
                style: TermexTypography.bodySmall.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: TermexSpacing.xs),
      child: ColoredBox(
        color: context.colors.border,
        child: SizedBox(height: 1, width: double.infinity),
      ),
    );
  }
}

