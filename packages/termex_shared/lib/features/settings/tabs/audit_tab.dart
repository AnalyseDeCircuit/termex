/// Audit log settings tab — thin wrapper around [AuditDashboard].
///
/// v0.77.0 PC final parity: closed the "AuditDashboard 完全缺失" gap from
/// v0.62.1 by replacing the previous bare ListView with a full KPI +
/// filter + paginated table dashboard. See [audit_dashboard.dart].
library;

import 'package:flutter/widgets.dart';

import 'audit/audit_dashboard.dart';

class AuditTab extends StatelessWidget {
  const AuditTab({super.key});

  @override
  Widget build(BuildContext context) => const AuditDashboard();
}
