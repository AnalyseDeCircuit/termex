import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/table.dart';

class _ServerRow {
  final String name;
  final String host;
  final int port;
  final String status;
  final String lastConnected;

  const _ServerRow({
    required this.name,
    required this.host,
    required this.port,
    required this.status,
    required this.lastConnected,
  });
}

const _mockRows = [
  _ServerRow(
    name: 'prod-web-01',
    host: '10.0.1.10',
    port: 22,
    status: 'online',
    lastConnected: '2 min ago',
  ),
  _ServerRow(
    name: 'prod-web-02',
    host: '10.0.1.11',
    port: 22,
    status: 'online',
    lastConnected: '5 min ago',
  ),
  _ServerRow(
    name: 'prod-db-01',
    host: '10.0.2.20',
    port: 2222,
    status: 'online',
    lastConnected: '1 hour ago',
  ),
  _ServerRow(
    name: 'prod-db-02',
    host: '10.0.2.21',
    port: 2222,
    status: 'offline',
    lastConnected: '2 days ago',
  ),
  _ServerRow(
    name: 'staging-api',
    host: '10.1.0.5',
    port: 22,
    status: 'online',
    lastConnected: '30 min ago',
  ),
  _ServerRow(
    name: 'staging-worker',
    host: '10.1.0.6',
    port: 22,
    status: 'online',
    lastConnected: '1 hour ago',
  ),
  _ServerRow(
    name: 'dev-build-01',
    host: '192.168.10.1',
    port: 22,
    status: 'offline',
    lastConnected: '1 week ago',
  ),
  _ServerRow(
    name: 'bastion',
    host: '203.0.113.5',
    port: 22,
    status: 'online',
    lastConnected: '3 min ago',
  ),
  _ServerRow(
    name: 'monitor',
    host: '10.0.9.1',
    port: 22,
    status: 'online',
    lastConnected: '10 min ago',
  ),
  _ServerRow(
    name: 'backup-01',
    host: '10.0.8.1',
    port: 22,
    status: 'offline',
    lastConnected: '3 weeks ago',
  ),
];

class TablePage extends StatelessWidget {
  const TablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DataTable',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Server List (10 rows)',
            child: SizedBox(
              height: 400,
              child: TermexDataTable<_ServerRow>(
                columns: [
                  TermexColumn<_ServerRow>(
                    id: 'name',
                    label: 'Name',
                    width: 160,
                    cellBuilder: (ctx, row) => Text(
                      row.name,
                      style: TermexTypography.bodySmall.copyWith(
                        color: TermexColors.textPrimary,
                      ),
                    ),
                  ),
                  TermexColumn<_ServerRow>(
                    id: 'host',
                    label: 'Host',
                    width: 140,
                    cellBuilder: (ctx, row) => Text(
                      row.host,
                      style: TermexTypography.bodySmall.copyWith(
                        color: TermexColors.textSecondary,
                      ),
                    ),
                  ),
                  TermexColumn<_ServerRow>(
                    id: 'port',
                    label: 'Port',
                    width: 80,
                    cellBuilder: (ctx, row) => Text(
                      '${row.port}',
                      style: TermexTypography.bodySmall.copyWith(
                        color: TermexColors.textSecondary,
                      ),
                    ),
                  ),
                  TermexColumn<_ServerRow>(
                    id: 'status',
                    label: 'Status',
                    width: 100,
                    cellBuilder: (ctx, row) => _StatusBadge(
                      status: row.status,
                    ),
                  ),
                  TermexColumn<_ServerRow>(
                    id: 'last_connected',
                    label: 'Last Connected',
                    cellBuilder: (ctx, row) => Text(
                      row.lastConnected,
                      style: TermexTypography.bodySmall.copyWith(
                        color: TermexColors.textMuted,
                      ),
                    ),
                  ),
                ],
                rows: _mockRows,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOnline = status == 'online';
    final color = isOnline ? TermexColors.success : TermexColors.neutral;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: TermexTypography.bodySmall.copyWith(color: color),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TermexTypography.heading4.copyWith(
            color: TermexColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
