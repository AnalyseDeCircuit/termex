/// Team settings tab — passphrase management + link to team dashboard.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
// Team collaboration is a Pro-edition feature shipped from termex_shared_pro
// (closed-source, under sibling repo termex-core-private/). The open-source
// desktop edition surfaces an informational stub instead of the full
// passphrase dialog. The Pro/Mobile edition composes termex_shared +
// termex_shared_pro and wires the real dialog at the app shell level.
// See docs/iterations/v0.69.0-pc-restructure-stabilization.md §7.
// import '../../team/team_passphrase_dialog.dart';  // moved to termex_shared_pro

class TeamTab extends ConsumerWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          '团队协作',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: TermexColors.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Text(
          '团队协作是 Pro 版功能。开源桌面版不包含完整的团队 dashboard '
          '及加密密码管理对话框。\n'
          '如需团队凭据共享、成员管理等能力，请使用 Termex 移动版或 Pro 桌面版。',
          style: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
        ),
      ],
    );
  }
}
