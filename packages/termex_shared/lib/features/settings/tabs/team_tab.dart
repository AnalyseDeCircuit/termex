/// Team settings tab — full dashboard (members + invites + conflicts + sync).
///
/// v0.77.0 PC final parity: replaces the previous "Team is a Pro feature"
/// stub with the real OSS dashboard, backed by the (already non-stubbed)
/// FRB endpoints in `team.rs`. See [TeamDashboard].
library;

import 'package:flutter/widgets.dart';

import '../../team/team_dashboard.dart';

class TeamTab extends StatelessWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context) => const TeamDashboard();
}
