import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'snippet_variable_resolver.dart';
import 'state/snippet_provider.dart';

class SnippetRow extends ConsumerWidget {
  final Snippet snippet;
  final void Function(String command)? onExecute;

  const SnippetRow({super.key, required this.snippet, this.onExecute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      snippet.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: TermexColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    ...snippet.tags.map((t) => _TagChip(tag: t)),
                    if (snippet.usageCount > 0) ...[
                      const Spacer(),
                      Text('使用 ${snippet.usageCount} 次',
                          style: TextStyle(fontSize: 10, color: TermexColors.textSecondary)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  snippet.content,
                  style: TextStyle(
                    fontSize: 11,
                    color: TermexColors.textSecondary,
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
                tooltip: '复制',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: snippet.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
              ),
              const SizedBox(width: 4),
              // Run
              _ActionBtn(
                icon: Icons.play_arrow_outlined,
                tooltip: '执行',
                color: TermexColors.success,
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
                tooltip: '编辑',
                onTap: () => ref.read(snippetProvider.notifier).setEditing(snippet.id),
              ),
              const SizedBox(width: 4),
              // Delete
              _ActionBtn(
                icon: Icons.delete_outline,
                tooltip: '删除',
                color: TermexColors.danger,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: Text('删除 Snippet', style: TextStyle(fontSize: 14, color: TermexColors.danger)),
        content: Text('确定要删除「${snippet.title}」吗？', style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: TermexColors.danger),
            child: const Text('删除'),
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
          color: TermexColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(tag, style: TextStyle(fontSize: 10, color: TermexColors.primary)),
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
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: TermexColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: TermexColors.border),
            ),
            child: Icon(icon, size: 14, color: color ?? TermexColors.textSecondary),
          ),
        ),
      );
}
