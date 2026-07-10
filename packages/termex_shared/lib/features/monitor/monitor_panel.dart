/// Live system-metrics dashboard for an SSH session.
///
/// Mirrors legacy Tauri's `MonitorPanel.vue`: info bar (OS / uptime / pause)
/// + 4-card metric grid (CPU / Memory / Disk / Network) + sortable process
/// list. Cards honour the user's per-panel show/hide settings.
///
/// Data source: [`monitorProvider`] which polls
/// `bridge.monitorGetStats(sessionId)` on the configured interval. The OSS
/// bridge returns zeroed `SystemStats` until the closed-source
/// `termex-core-private` crate provides real remote collection — same
/// behaviour as the legacy Tauri OSS build, which gates collection behind
/// the `private` Cargo feature.
///
/// v0.77.0 PC final parity: restored to OSS termex_shared (was deleted in
/// v0.69 restructure and marked "Pro forever stub").
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../icons/termex_icons.dart';
import '../settings/state/settings_provider.dart';
import 'state/monitor_provider.dart';
import 'widgets/metric_cards.dart';
import 'widgets/process_list.dart';

class MonitorPanel extends ConsumerStatefulWidget {
  final String sessionId;
  const MonitorPanel({super.key, required this.sessionId});

  @override
  ConsumerState<MonitorPanel> createState() => _MonitorPanelState();
}

class _MonitorPanelState extends ConsumerState<MonitorPanel> {
  ProcessSort _sort = ProcessSort.cpu;
  bool _autoStartTried = false;

  @override
  void initState() {
    super.initState();
  }

  void _maybeAutoStart() {
    if (_autoStartTried) return;
    _autoStartTried = true;
    final s = ref.read(settingsProvider).settings;
    if (s.monitorAutoStart) {
      ref
          .read(monitorProvider(widget.sessionId).notifier)
          .start(intervalMs: s.monitorIntervalMs);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoStart());
    final state = ref.watch(monitorProvider(widget.sessionId));
    final settings = ref.watch(settingsProvider).settings;

    final latest = state.latest;
    if (latest == null) {
      return _LoadingView(
        isCollecting: state.isCollecting,
        onStart: () => ref
            .read(monitorProvider(widget.sessionId).notifier)
            .start(intervalMs: settings.monitorIntervalMs),
        error: state.errorMessage,
      );
    }

    return Container(
      color: TermexColors.backgroundPrimary,
      padding: const EdgeInsets.all(TermexSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoBar(
            isCollecting: state.isCollecting,
            sessionId: widget.sessionId,
            stubbed: state.looksStubbed,
            onToggle: () {
              final notifier =
                  ref.read(monitorProvider(widget.sessionId).notifier);
              if (state.isCollecting) {
                notifier.stop();
              } else {
                notifier.start(intervalMs: settings.monitorIntervalMs);
              }
            },
          ),
          const SizedBox(height: TermexSpacing.md),
          if (state.looksStubbed)
            const Padding(
              padding: EdgeInsets.only(bottom: TermexSpacing.md),
              child: _StubBanner(),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final twoCol = c.maxWidth >= 600;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MetricGrid(
                        latest: latest,
                        history: state.history,
                        showCpu: settings.monitorShowCpu,
                        showMemory: settings.monitorShowMemory,
                        showDisk: settings.monitorShowDisk,
                        showNetwork: settings.monitorShowNetwork,
                        twoColumn: twoCol,
                      ),
                      if (settings.monitorShowProcesses) ...[
                        const SizedBox(height: TermexSpacing.md),
                        ProcessListView(
                          processes: state.processes,
                          sort: _sort,
                          onSortChanged: (s) => setState(() => _sort = s),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info bar ─────────────────────────────────────────────────────────────

class _InfoBar extends StatelessWidget {
  final bool isCollecting;
  final bool stubbed;
  final String sessionId;
  final VoidCallback onToggle;

  const _InfoBar({
    required this.isCollecting,
    required this.stubbed,
    required this.sessionId,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '系统监控',
          style: TermexTypography.body.copyWith(
            color: TermexColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: TermexSpacing.sm),
        if (!isCollecting)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: TermexColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'PAUSED',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.warning,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Spacer(),
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TermexSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isCollecting
                  ? TermexColors.danger.withValues(alpha: 0.12)
                  : TermexColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCollecting
                    ? TermexColors.danger.withValues(alpha: 0.4)
                    : TermexColors.success.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TermexIconWidget(
                  isCollecting ? TermexIcons.disconnect : TermexIcons.connect,
                  size: 11,
                  color:
                      isCollecting ? TermexColors.danger : TermexColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  isCollecting ? '停止' : '开始',
                  style: TermexTypography.caption.copyWith(
                    color: isCollecting
                        ? TermexColors.danger
                        : TermexColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stub banner ──────────────────────────────────────────────────────────

class _StubBanner extends StatelessWidget {
  const _StubBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.sm),
      decoration: BoxDecoration(
        color: TermexColors.warning.withValues(alpha: 0.08),
        border: Border.all(
          color: TermexColors.warning.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const TermexIconWidget(
            TermexIcons.help,
            size: 12,
            color: TermexColors.warning,
          ),
          const SizedBox(width: TermexSpacing.sm),
          Expanded(
            child: Text(
              '当前以 OSS 桥接 stub 运行（全 0 数据）。远程系统指标真实采集由商业版 '
              '`termex-core-private` 提供，与旧 Tauri OSS 行为一致。',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Metric grid ──────────────────────────────────────────────────────────

class _MetricGrid extends StatelessWidget {
  final dynamic latest; // bridge.SystemStats — kept dynamic to avoid extra import
  final List<dynamic> history;
  final bool showCpu, showMemory, showDisk, showNetwork;
  final bool twoColumn;

  const _MetricGrid({
    required this.latest,
    required this.history,
    required this.showCpu,
    required this.showMemory,
    required this.showDisk,
    required this.showNetwork,
    required this.twoColumn,
  });

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (showCpu)
        SizedBox(
          height: 140,
          child: CpuCard(latest: latest, history: history.cast()),
        ),
      if (showMemory)
        SizedBox(
          height: 140,
          child: MemoryCard(latest: latest, history: history.cast()),
        ),
      if (showDisk)
        SizedBox(
          height: 140,
          child: DiskCard(latest: latest),
        ),
      if (showNetwork)
        SizedBox(
          height: 140,
          child: NetworkCard(latest: latest, history: history.cast()),
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();

    if (twoColumn) {
      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i += 2) {
        final left = cards[i];
        final right = i + 1 < cards.length ? cards[i + 1] : const SizedBox();
        rows.add(Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: TermexSpacing.md),
            Expanded(child: right),
          ],
        ));
        if (i + 2 < cards.length) {
          rows.add(const SizedBox(height: TermexSpacing.md));
        }
      }
      return Column(children: rows);
    }
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i < cards.length - 1) const SizedBox(height: TermexSpacing.md),
        ],
      ],
    );
  }
}

// ─── Loading / empty ──────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final bool isCollecting;
  final VoidCallback onStart;
  final String? error;

  const _LoadingView({
    required this.isCollecting,
    required this.onStart,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TermexColors.backgroundPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TermexIconWidget(
              TermexIcons.server,
              size: 40,
              color: TermexColors.textMuted,
            ),
            const SizedBox(height: TermexSpacing.md),
            Text(
              isCollecting ? '采集指标中…' : '监控未启动',
              style: TermexTypography.body.copyWith(
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(height: TermexSpacing.sm),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: TermexSpacing.sm,
                  left: TermexSpacing.lg,
                  right: TermexSpacing.lg,
                ),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TermexTypography.caption.copyWith(
                    color: TermexColors.danger,
                  ),
                ),
              ),
            if (!isCollecting)
              GestureDetector(
                onTap: onStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TermexSpacing.lg,
                    vertical: TermexSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: TermexColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '开始采集',
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
