import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/team_provider.dart';

class TeamConflictDialog extends ConsumerWidget {
  final TeamConflict conflict;
  const TeamConflictDialog({super.key, required this.conflict});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: Row(
        children: [
          Icon(Icons.merge_type, size: 18, color: TermexColors.warning),
          const SizedBox(width: 8),
          Text('同步冲突', style: TextStyle(fontSize: 15, color: TermexColors.textPrimary)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${conflict.resourceType} "${conflict.resourceName}" 存在冲突，请选择保留哪个版本：',
              style: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _VersionCard(
                    title: '本地版本',
                    content: conflict.localVersion,
                    icon: Icons.computer,
                    color: TermexColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VersionCard(
                    title: '远程版本',
                    content: conflict.remoteVersion,
                    icon: Icons.cloud_outlined,
                    color: TermexColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('稍后处理', style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
        ),
        OutlinedButton(
          onPressed: () {
            ref.read(teamProvider.notifier).resolveConflict(conflict.id, false);
            Navigator.pop(context);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: TermexColors.success,
            side: BorderSide(color: TermexColors.success),
            minimumSize: const Size(80, 32),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('使用远程'),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(teamProvider.notifier).resolveConflict(conflict.id, true);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: TermexColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('使用本地'),
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _VersionCard({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 11,
              color: TermexColors.textPrimary,
              fontFamily: 'monospace',
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
