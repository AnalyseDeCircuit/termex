/// Four metric cards rendered inside the Monitor panel grid.
///
/// Each card pulls its current value from the latest `SystemStats` and a
/// short history series from the buffered `history`. Cards are intentionally
/// dumb — all state lives in `MonitorProvider`.
library;

import 'package:flutter/widgets.dart';
import 'package:termex_bridge/api.dart' as bridge;

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import 'sparkline.dart';

double _pctNorm(double v) => (v / 100).clamp(0.0, 1.0);

String _humanBytes(num b) {
  if (b < 1024) return '${b.toStringAsFixed(0)} B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

// ─── CPU ──────────────────────────────────────────────────────────────────

class CpuCard extends StatelessWidget {
  final bridge.SystemStats latest;
  final List<bridge.SystemStats> history;

  const CpuCard({super.key, required this.latest, required this.history});

  @override
  Widget build(BuildContext context) {
    final series = history.map((s) => _pctNorm(s.cpuPercent.toDouble())).toList();
    return _Card(
      title: 'CPU',
      mainValue: '${latest.cpuPercent.toStringAsFixed(1)}%',
      accent: context.colors.primary,
      child: Sparkline(values: series.cast<double?>(), color: context.colors.primary),
    );
  }
}

// ─── Memory ───────────────────────────────────────────────────────────────

class MemoryCard extends StatelessWidget {
  final bridge.SystemStats latest;
  final List<bridge.SystemStats> history;

  const MemoryCard({super.key, required this.latest, required this.history});

  @override
  Widget build(BuildContext context) {
    final total = latest.memTotalMb.toInt();
    final used = latest.memUsedMb.toInt();
    final pct = total > 0 ? (used / total) * 100 : 0.0;
    final series = history.map((s) {
      final t = s.memTotalMb.toInt();
      final u = s.memUsedMb.toInt();
      return t > 0 ? _pctNorm(u / t * 100) : 0.0;
    }).toList();
    return _Card(
      title: 'Memory',
      mainValue: '${pct.toStringAsFixed(1)}%',
      sub: '$used / $total MB',
      accent: const Color(0xFF8B5CF6),
      child: Sparkline(
        values: series.cast<double?>(),
        color: const Color(0xFF8B5CF6),
      ),
    );
  }
}

// ─── Disk ─────────────────────────────────────────────────────────────────

class DiskCard extends StatelessWidget {
  final bridge.SystemStats latest;

  const DiskCard({super.key, required this.latest});

  @override
  Widget build(BuildContext context) {
    final total = latest.diskTotalGb;
    final used = latest.diskUsedGb;
    final pct = total > 0 ? (used / total) * 100 : 0.0;
    return _Card(
      title: 'Disk',
      mainValue: '${pct.toStringAsFixed(1)}%',
      sub: '${used.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} GB',
      accent: context.colors.warning,
      child: _UsageBar(
        ratio: pct / 100,
        color: context.colors.warning,
      ),
    );
  }
}

// ─── Network ──────────────────────────────────────────────────────────────

class NetworkCard extends StatelessWidget {
  final bridge.SystemStats latest;
  final List<bridge.SystemStats> history;

  const NetworkCard({super.key, required this.latest, required this.history});

  @override
  Widget build(BuildContext context) {
    final rx = latest.netRxBytes.toInt();
    final tx = latest.netTxBytes.toInt();
    // Derive per-tick deltas for the sparkline so the y-axis represents
    // bytes/sec not cumulative totals.
    final maxDelta = history.isEmpty
        ? 1.0
        : _maxDelta(history, (s) => s.netRxBytes.toInt());
    final rxSeries = _deltaSeries(history, (s) => s.netRxBytes.toInt(), maxDelta);
    final txSeries = _deltaSeries(history, (s) => s.netTxBytes.toInt(), maxDelta);

    return _Card(
      title: 'Network',
      mainValue: '↓ ${_humanBytes(rx)}',
      sub: '↑ ${_humanBytes(tx)}',
      accent: context.colors.success,
      child: Column(
        children: [
          Expanded(
            child: Sparkline(
              values: rxSeries,
              color: context.colors.success,
              height: 14,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Sparkline(
              values: txSeries,
              color: context.colors.warning,
              height: 14,
            ),
          ),
        ],
      ),
    );
  }

  static double _maxDelta(
      List<bridge.SystemStats> hist, int Function(bridge.SystemStats) f) {
    var m = 1.0;
    for (var i = 1; i < hist.length; i++) {
      final d = (f(hist[i]) - f(hist[i - 1])).toDouble().abs();
      if (d > m) m = d;
    }
    return m;
  }

  static List<double?> _deltaSeries(
    List<bridge.SystemStats> hist,
    int Function(bridge.SystemStats) f,
    double max,
  ) {
    if (hist.isEmpty || max <= 0) return const [];
    final out = <double?>[null];
    for (var i = 1; i < hist.length; i++) {
      final d = (f(hist[i]) - f(hist[i - 1])).toDouble().abs();
      out.add((d / max).clamp(0.0, 1.0));
    }
    return out;
  }
}

// ─── Shared card frame ───────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final String mainValue;
  final String? sub;
  final Color accent;
  final Widget child;

  const _Card({
    required this.title,
    required this.mainValue,
    this.sub,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: context.colors.border, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: TermexSpacing.sm),
              Text(
                title,
                style: TermexTypography.caption.copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: TermexSpacing.sm),
          Text(
            mainValue,
            style: TermexTypography.body.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: TermexTypography.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: TermexSpacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final double ratio;
  final Color color;

  const _UsageBar({required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    final r = ratio.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (ctx, c) => Stack(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: context.colors.backgroundTertiary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            height: 6,
            width: c.maxWidth * r,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}
