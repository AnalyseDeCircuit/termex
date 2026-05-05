import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/monitor_provider.dart';

/// System resource monitor panel — resource gauges + process list.
class MonitorPanel extends ConsumerStatefulWidget {
  final String sessionId;

  const MonitorPanel({super.key, required this.sessionId});

  @override
  ConsumerState<MonitorPanel> createState() => _MonitorPanelState();
}

class _MonitorPanelState extends ConsumerState<MonitorPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(monitorProvider.notifier)
          .startPolling(widget.sessionId);
      ref
          .read(monitorProvider.notifier)
          .refreshProcesses(widget.sessionId);
    });
  }

  @override
  void dispose() {
    ref.read(monitorProvider.notifier).stopPolling();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monitorProvider);

    return Container(
      color: TermexColors.backgroundPrimary,
      child: Column(
        children: [
          _Header(sessionId: widget.sessionId, isPolling: state.isPolling),
          TabBar(
            controller: _tab,
            labelColor: TermexColors.primary,
            unselectedLabelColor: TermexColors.textSecondary,
            indicatorColor: TermexColors.primary,
            tabs: const [Tab(text: 'Overview'), Tab(text: 'Processes')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _OverviewTab(state: state),
                _ProcessTab(state: state, sessionId: widget.sessionId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final String sessionId;
  final bool isPolling;

  const _Header({required this.sessionId, required this.isPolling});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monitor_heart_outlined,
              size: 16, color: TermexColors.primary),
          const SizedBox(width: 8),
          const Text('Monitor',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: TermexColors.textPrimary)),
          const Spacer(),
          if (isPolling)
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: TermexColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Live',
                    style: TextStyle(
                        fontSize: 11, color: TermexColors.textSecondary)),
              ],
            ),
          const SizedBox(width: 12),
          _ActionButton(
            icon: isPolling ? Icons.pause : Icons.play_arrow,
            onTap: () {
              final n = ref.read(monitorProvider.notifier);
              if (isPolling) {
                n.stopPolling();
              } else {
                n.startPolling(sessionId);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final MonitorState state;

  const _OverviewTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    if (stats == null) {
      return const Center(
        child: Text('Waiting for data…',
            style: TextStyle(color: TermexColors.textSecondary)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GaugeCard(label: 'CPU', value: stats.cpuPercent / 100,
              display: '${stats.cpuPercent.toStringAsFixed(1)}%',
              color: _cpuColor(stats.cpuPercent)),
          const SizedBox(height: 12),
          _GaugeCard(
            label: 'Memory',
            value: stats.memPercent,
            display: '${stats.memUsedMb} MB / ${stats.memTotalMb} MB',
            color: _memColor(stats.memPercent),
          ),
          const SizedBox(height: 12),
          _GaugeCard(
            label: 'Disk',
            value: stats.diskPercent,
            display:
                '${stats.diskUsedGb.toStringAsFixed(1)} GB / ${stats.diskTotalGb.toStringAsFixed(1)} GB',
            color: _diskColor(stats.diskPercent),
          ),
          const SizedBox(height: 12),
          _NetworkCard(
            rxBytes: stats.netRxBytes,
            txBytes: stats.netTxBytes,
          ),
          if (state.history.length > 1) ...[
            const SizedBox(height: 16),
            const Text('CPU History (last 60s)',
                style: TextStyle(
                    fontSize: 11, color: TermexColors.textSecondary)),
            const SizedBox(height: 8),
            _SparklineChart(
                samples: state.history
                    .map((s) => s.cpuPercent / 100)
                    .toList()),
          ],
        ],
      ),
    );
  }

  Color _cpuColor(double pct) {
    if (pct > 80) return TermexColors.danger;
    if (pct > 60) return TermexColors.warning;
    return TermexColors.success;
  }

  Color _memColor(double frac) {
    if (frac > 0.9) return TermexColors.danger;
    if (frac > 0.75) return TermexColors.warning;
    return TermexColors.primary;
  }

  Color _diskColor(double frac) {
    if (frac > 0.95) return TermexColors.danger;
    if (frac > 0.8) return TermexColors.warning;
    return TermexColors.neutral;
  }
}

// ─── Gauge Card ───────────────────────────────────────────────────────────────

class _GaugeCard extends StatelessWidget {
  final String label;
  final double value; // 0–1
  final String display;
  final Color color;

  const _GaugeCard({
    required this.label,
    required this.value,
    required this.display,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TermexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: TermexColors.textSecondary)),
            const Spacer(),
            Text(display,
                style: const TextStyle(
                    fontSize: 12, color: TermexColors.textPrimary)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: TermexColors.backgroundTertiary,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Network Card ─────────────────────────────────────────────────────────────

class _NetworkCard extends StatelessWidget {
  final int rxBytes;
  final int txBytes;

  const _NetworkCard({required this.rxBytes, required this.txBytes});

  String _fmt(int b) {
    if (b < 1024) return '$b B/s';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB/s';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TermexColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_downward, size: 14, color: TermexColors.success),
          const SizedBox(width: 4),
          Text(_fmt(rxBytes),
              style: const TextStyle(
                  fontSize: 12, color: TermexColors.textPrimary)),
          const SizedBox(width: 24),
          const Icon(Icons.arrow_upward, size: 14, color: TermexColors.primary),
          const SizedBox(width: 4),
          Text(_fmt(txBytes),
              style: const TextStyle(
                  fontSize: 12, color: TermexColors.textPrimary)),
        ],
      ),
    );
  }
}

// ─── Sparkline Chart ──────────────────────────────────────────────────────────

class _SparklineChart extends StatelessWidget {
  final List<double> samples; // values 0–1

  const _SparklineChart({required this.samples});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: CustomPaint(
        painter: _SparklinePainter(samples),
        size: const Size(double.infinity, 48),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> samples;

  _SparklinePainter(this.samples);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    final paint = Paint()
      ..color = TermexColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = i / (samples.length - 1) * size.width;
      final y = (1 - samples[i].clamp(0.0, 1.0)) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.samples != samples;
}

// ─── Process Tab ──────────────────────────────────────────────────────────────

class _ProcessTab extends ConsumerWidget {
  final MonitorState state;
  final String sessionId;

  const _ProcessTab({required this.state, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.processes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No process data',
                style: TextStyle(color: TermexColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref
                  .read(monitorProvider.notifier)
                  .refreshProcesses(sessionId),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(foregroundColor: TermexColors.primary),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        _ProcessHeader(sessionId: sessionId),
        Expanded(
          child: ListView.builder(
            itemCount: state.processes.length,
            itemBuilder: (_, i) => _ProcessRow(
              process: state.processes[i],
              sessionId: sessionId,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProcessHeader extends ConsumerWidget {
  final String sessionId;

  const _ProcessHeader({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          const _Col('PID', 60),
          const _Col('Name', 160),
          const _Col('CPU%', 60),
          const _Col('Mem', 60),
          const _Col('User', 100),
          const Spacer(),
          _ActionButton(
            icon: Icons.refresh,
            onTap: () => ref
                .read(monitorProvider.notifier)
                .refreshProcesses(sessionId),
          ),
        ],
      ),
    );
  }
}

class _Col extends StatelessWidget {
  final String text;
  final double width;

  const _Col(this.text, this.width);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: TermexColors.textSecondary,
                fontWeight: FontWeight.w600)),
      );
}

class _ProcessRow extends ConsumerWidget {
  final ProcessInfo process;
  final String sessionId;

  const _ProcessRow({required this.process, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onSecondaryTapDown: (d) => _showSignalMenu(context, d.globalPosition, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: TermexColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text('${process.pid}',
                  style: const TextStyle(
                      fontSize: 11, color: TermexColors.textMuted,
                      fontFamily: 'monospace')),
            ),
            SizedBox(
              width: 160,
              child: Text(process.name,
                  style: const TextStyle(
                      fontSize: 12, color: TermexColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 60,
              child: Text('${process.cpuPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 11,
                      color: process.cpuPercent > 50
                          ? TermexColors.warning
                          : TermexColors.textSecondary)),
            ),
            SizedBox(
              width: 60,
              child: Text('${process.memMb} MB',
                  style: const TextStyle(
                      fontSize: 11, color: TermexColors.textSecondary)),
            ),
            SizedBox(
              width: 100,
              child: Text(process.user,
                  style: const TextStyle(
                      fontSize: 11, color: TermexColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignalMenu(BuildContext context, Offset pos, WidgetRef ref) {
    const signals = ['SIGTERM', 'SIGKILL', 'SIGUSR1', 'SIGUSR2'];
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      color: TermexColors.backgroundSecondary,
      items: signals
          .map((s) => PopupMenuItem(
                value: s,
                height: 36,
                child: Text(s,
                    style: const TextStyle(
                        fontSize: 12, color: TermexColors.textPrimary)),
              ))
          .toList(),
    ).then((signal) {
      if (signal != null) {
        ref
            .read(monitorProvider.notifier)
            .sendSignal(sessionId, process.pid, signal);
      }
    });
  }
}

// ─── Shared ───────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: TermexColors.textSecondary),
        ),
      );
}
