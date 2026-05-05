/// Team settings tab — passphrase management + link to team dashboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../team/team_passphrase_dialog.dart';

class TeamTab extends ConsumerWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '团队协作',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: TermexColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '完整团队 dashboard 在侧边栏「团队」入口打开。',
          style: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => showTeamPassphraseDialog(context),
          icon: const Icon(Icons.key, size: 14),
          label: const Text('修改团队加密密码', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: TermexColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
