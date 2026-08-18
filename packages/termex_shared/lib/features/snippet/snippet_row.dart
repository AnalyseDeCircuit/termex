import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../icons/termex_icons.dart';
import '../../widgets/clickable.dart';
import '../../widgets/menu.dart';
import '../../widgets/panel_context_menu.dart';
import '../../widgets/toast.dart';
import 'snippet_variable_resolver.dart';
import 'state/snippet_provider.dart';

class SnippetRow extends ConsumerWidget {
  final Snippet snippet;
  final void Function(String command)? onExecute;

  const SnippetRow({super.key, required this.snippet, this.onExecute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Consumes the gesture so the panel's blank-area menu does not also
      // fire for a click that landed on a row.
      onSecondaryTapUp: (d) => _showRowMenu(context, ref, d.globalPosition),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: context.colors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: title (ellipsis) + usage count (固定右侧)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        snippet.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    if (snippet.usageCount > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        l10n.snippetUsageTimes(snippet.usageCount),
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                // Line 2: tags wrap — narrow sidebars get multi-row tags
                // instead of overflowing horizontally.
                if (snippet.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: snippet.tags
                        .map((t) => _TagChip(tag: t))
                        .toList(growable: false),
                  ),
                ],
                // Line 3: command preview
                const SizedBox(height: 4),
                Text(
                  snippet.content,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Copy
              _ActionBtn(
                icon: Icons.copy_outlined,
                tooltip: l10n.snippetCopy,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: snippet.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.snippetCopiedToClipboard)),
                  );
                },
              ),
              const SizedBox(width: 4),
              // Run
              _ActionBtn(
                icon: Icons.play_arrow_outlined,
                tooltip: l10n.snippetExecute,
                color: context.colors.success,
                onTap: () async {
                  final cmd = await resolveSnippetVariables(context, snippet);
                  if (cmd != null) {
                    ref.read(snippetProvider.notifier).incrementUsage(snippet.id);
                    onExecute?.call(cmd);
                  }
                },
              ),
              const SizedBox(width: 4),
              // Edit
              _ActionBtn(
                icon: Icons.edit_outlined,
                tooltip: l10n.commonEdit,
                onTap: () => ref.read(snippetProvider.notifier).setEditing(snippet.id),
              ),
              const SizedBox(width: 4),
              // Delete
              _ActionBtn(
                icon: Icons.delete_outline,
                tooltip: l10n.commonDelete,
                color: context.colors.danger,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  /// Row menu — the same four actions the inline buttons offer, plus a
  /// dedicated copy entry. The buttons are 4 icons crammed into a 240pt
  /// sidebar; the menu labels them.
  void _showRowMenu(BuildContext context, WidgetRef ref, Offset position) {
    final l10n = AppLocalizations.of(context);
    showContextMenu(
      context: context,
      position: position,
      items: [
        MenuItem(
          label: l10n.snippetExecute,
          icon: menuIcon(context, TermexIcons.play),
          onSelected: () => _execute(context, ref),
        ),
        MenuItem(
          label: l10n.ctxSnippetCopyContent,
          icon: menuIcon(context, TermexIcons.copy),
          onSelected: () {
            Clipboard.setData(ClipboardData(text: snippet.content));
            ToastController.success(l10n.snippetCopiedToClipboard);
          },
        ),
        const MenuItem.separator(),
        MenuItem(
          label: l10n.snippetEdit,
          icon: menuIcon(context, TermexIcons.edit),
          onSelected: () =>
              ref.read(snippetProvider.notifier).setEditing(snippet.id),
        ),
        const MenuItem.separator(),
        deleteMenuItem(
          context,
          label: l10n.snippetDelete,
          onSelected: () => _confirmDelete(context, ref),
        ),
      ],
    );
  }

  Future<void> _execute(BuildContext context, WidgetRef ref) async {
    final cmd = await resolveSnippetVariables(context, snippet);
    if (cmd != null) {
      ref.read(snippetProvider.notifier).incrementUsage(snippet.id);
      onExecute?.call(cmd);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.backgroundSecondary,
        title: Text(l10n.snippetDeleteTitle, style: TextStyle(fontSize: 14, color: context.colors.danger)),
        content: Text(l10n.snippetDeleteConfirmNamed(snippet.title), style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(snippetProvider.notifier).delete(snippet.id);
    }
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: context.colors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(tag, style: TextStyle(fontSize: 10, color: context.colors.primary)),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Clickable(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: context.colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(icon, size: 14, color: color ?? context.colors.textSecondary),
          ),
        ),
      );
}
