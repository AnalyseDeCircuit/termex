/// Riverpod state holding live + historical SystemStats for one SSH session.
///
/// Polls `bridge.monitorGetStats(sessionId)` on a settings-driven interval,
/// keeps the last N samples (default 60 = 2 min @ 2 s) for sparklines, and
/// surfaces the most-recent reading + ProcessInfo list. Auto-starts on
/// first watch; cleanly tears down via `ref.onDispose` so closing the tab
/// (which removes the provider's listeners) stops the timer and the
/// matching Rust-side `monitor_stop_polling`.
///
/// v0.77.0 PC final parity: backs `MonitorPanel` (restored OSS counterpart
/// to legacy Tauri's MonitorPanel.vue).
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

const int _kHistoryCap = 60;

@immutable
class MonitorState {
  final bool isCollecting;
  final bridge.SystemStats? latest;
  final List<bridge.SystemStats> history;
  final List<bridge.ProcessInfo> processes;
  final String? errorMessage;

  const MonitorState({
    this.isCollecting = false,
    this.latest,
    this.history = const [],
    this.processes = const [],
    this.errorMessage,
  });

  MonitorState copyWith({
    bool? isCollecting,
    bridge.SystemStats? latest,
    List<bridge.SystemStats>? history,
    List<bridge.ProcessInfo>? processes,
    String? errorMessage,
    bool clearError = false,
  }) =>
      MonitorState(
        isCollecting: isCollecting ?? this.isCollecting,
        latest: latest ?? this.latest,
        history: history ?? this.history,
        processes: processes ?? this.processes,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  /// True when the OSS bridge stub returns all-zero data — the panel uses
  /// this to surface a "Pro integration needed" hint instead of a sea of
  /// 0% gauges.
  bool get looksStubbed {
    final l = latest;
    if (l == null) return false;
    return l.cpuPercent == 0 &&
        l.memTotalMb == BigInt.zero &&
        l.diskTotalGb == 0;
  }
}

class MonitorNotifier extends FamilyNotifier<MonitorState, String> {
  Timer? _timer;
  int _intervalMs = 2000;

  @override
  MonitorState build(String sessionId) {
    ref.onDispose(_stop);
    return const MonitorState();
  }

  Future<void> start({int intervalMs = 2000}) async {
    if (state.isCollecting) return;
    _intervalMs = intervalMs.clamp(250, 30000);
    try {
      await bridge.monitorStartPolling(
        sessionId: arg,
        intervalMs: _intervalMs,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: '启动监控失败：$e');
      return;
    }
    state = state.copyWith(isCollecting: true, clearError: true);
    await _tick();
    _timer = Timer.periodic(Duration(milliseconds: _intervalMs), (_) => _tick());
  }

  Future<void> stop() async {
    if (!state.isCollecting) return;
    _stop();
    try {
      await bridge.monitorStopPolling(sessionId: arg);
    } catch (_) {/* ignore: tearing down */}
    state = state.copyWith(isCollecting: false);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    try {
      final stats = await bridge.monitorGetStats(sessionId: arg);
      final procs = await bridge.monitorListProcesses(
        sessionId: arg,
        limit: 20,
      );
      final next = [...state.history, stats];
      if (next.length > _kHistoryCap) {
        next.removeRange(0, next.length - _kHistoryCap);
      }
      state = state.copyWith(
        latest: stats,
        history: next,
        processes: procs,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: '采集失败：$e');
    }
  }
}

final monitorProvider =
    NotifierProvider.family<MonitorNotifier, MonitorState, String>(
  MonitorNotifier.new,
);
