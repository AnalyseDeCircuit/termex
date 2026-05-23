/// Tmux window/pane status bar renderer.
///
/// Displays a horizontal list of tmux windows at the bottom of the terminal
/// pane when [TmuxController.isAttached] is true.  Clicking a window tab
/// selects it; right-click shows a context menu with rename/close.
library;

import 'package:flutter/material.dart';

import '../../../../design/colors.dart';
import '../../../../design/typography.dart';
import 'tmux_controller.dart';

export 'tmux_controller.dart';

/// Status bar that shows tmux window tabs.
///
/// Place at the bottom of the terminal view inside a [Column].
/// Renders nothing when the controller is not attached.
class TmuxWindowBar extends StatelessWidget {
  final TmuxController controller;

  const TmuxWindowBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isAttached || controller.windows.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 28,
          color: TermexColors.backgroundTertiary,
          child: Row(
            children: [
              // Tmux indicator
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '[tmux]',
                  style: TextStyle(
                    fontSize: 10,
                    color: TermexColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(width: 1, height: 16, color: TermexColors.border),
              // Window tabs
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: controller.windowList.length,
                  itemBuilder: (context, i) {
                    final window = controller.windowList[i];
                    return _WindowTab(
                      window: window,
                      isActive: window.index == controller.activeWindowIndex,
                      onTap: () => controller.selectWindow(window.index),
                      onClose: () => controller.closeWindow(window.index),
                      onRename: (name) =>
                          controller.renameWindow(window.index, name),
                    );
                  },
                ),
              ),
              // New window button
              _IconBtn(
                tooltip: '新建窗口',
                icon: Icons.add,
                onTap: controller.newWindow,
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }
}

class _WindowTab extends StatelessWidget {
  final TmuxWindow window;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ValueChanged<String> onRename;

  const _WindowTab({
    required this.window,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? TermexColors.backgroundSecondary
              : Colors.transparent,
          border: Border(
            top: BorderSide(
              color: isActive ? TermexColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${window.index}: ${window.name}',
              style: TermexTypography.monospace.copyWith(
                fontSize: 12,
                color: isActive
                    ? TermexColors.textPrimary
                    : TermexColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            // Pane count badge
            if (window.panes.length > 1)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: TermexColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${window.panes.length}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: TermexColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: TermexColors.backgroundSecondary,
      items: [
        const PopupMenuItem(value: 'rename', child: Text('重命名窗口')),
        const PopupMenuItem(value: 'close', child: Text('关闭窗口')),
      ],
    );

    if (!context.mounted) return;

    switch (result) {
      case 'rename':
        final name = await _promptRename(context);
        if (name != null && name.isNotEmpty) onRename(name);
      case 'close':
        onClose();
    }
  }

  Future<String?> _promptRename(BuildContext context) async {
    final ctrl = TextEditingController(text: window.name);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: const Text('重命名窗口',
            style: TextStyle(color: TermexColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: TermexColors.textPrimary),
          decoration: const InputDecoration(
            hintText: '窗口名称',
            hintStyle: TextStyle(color: TermexColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Icon(Icons.add, size: 14, color: TermexColors.textSecondary),
        ),
      ),
    );
  }
}
