/// Team settings tab — passphrase management + link to team dashboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
// Team feature is temporarily detached during the v0.69.0+ desktop/mobile
// package split. The passphrase dialog will be re-introduced once team/
// lands in its final location (termex_shared / termex-mobile). Until then
// the button shows a placeholder snackbar.
// import '../../team/team_passphrase_dialog.dart';

class TeamTab extends ConsumerWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '团队协作',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: TermexColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '完整团队 dashboard 在侧边栏「团队」入口打开。',
          style: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Team passphrase dialog is being relocated; please retry '
                    'after the v0.69+ restructure stabilizes.'),
              ),
            );
          },
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
