import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

// ─── DTOs ────────────────────────────────────────────────────────────────────

class SystemStats {
  final double cpuPercent;
  final int memUsedMb;
  final int memTotalMb;
  final double diskUsedGb;
  final double diskTotalGb;
  final int netRxBytes;
  final int netTxBytes;
  final String timestamp;

  const SystemStats({
    required this.cpuPercent,
    required this.memUsedMb,
    required this.memTotalMb,
    required this.diskUsedGb,
    required this.diskTotalGb,
    required this.netRxBytes,
    required this.netTxBytes,
    required this.timestamp,
  });

  double get memPercent =>
      memTotalMb == 0 ? 0 : memUsedMb / memTotalMb;

  double get diskPercent =>
      diskTotalGb == 0 ? 0 : diskUsedGb / diskTotalGb;

  factory SystemStats.zero() => SystemStats(
        cpuPercent: 0,
        memUsedMb: 0,
        memTotalMb: 0,
        diskUsedGb: 0,
        diskTotalGb: 0,
        netRxBytes: 0,
        netTxBytes: 0,
        timestamp: DateTime.now().toIso8601String(),
      );
}

class ProcessInfo {
  final int pid;
  final String name;
  final double cpuPercent;
  final int memMb;
  final String status;
  final String user;

  const ProcessInfo({
    required this.pid,
    required this.name,
    required this.cpuPercent,
    required this.memMb,
    required this.status,
    required this.user,
  });
}

// ─── State ────────────────────────────────────────────────────────────────────

class MonitorState {
  final SystemStats? stats;
  final List<ProcessInfo> processes;
  final bool isPolling;
  final bool isLoading;
  final String? error;
  final List<SystemStats> history;

  const MonitorState({
    this.stats,
    this.processes = const [],
    this.isPolling = false,
    this.isLoading = false,
    this.error,
    this.history = const [],
  });

  MonitorState copyWith({
    SystemStats? stats,
    List<ProcessInfo>? processes,
    bool? isPolling,
    bool? isLoading,
    String? error,
    List<SystemStats>? history,
    bool clearError = false,
  }) =>
      MonitorState(
        stats: stats ?? this.stats,
        processes: processes ?? this.processes,
        isPolling: isPolling ?? this.isPolling,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        history: history ?? this.history,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class MonitorNotifier extends Notifier<MonitorState> {
  Timer? _pollTimer;
  static const _historyMax = 60;

  @override
  MonitorState build() => const MonitorState();

  Future<void> startPolling(String sessionId, {int intervalMs = 2000}) async {
    if (state.isPolling) return;
    state = state.copyWith(isPolling: true, clearError: true);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _tick(sessionId);
    });
    await _tick(sessionId);
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    state = state.copyWith(isPolling: false);
  }

  Future<void> _tick(String sessionId) async {
    // Stub: produce incrementally changing stats until FRB is wired.
    final now = DateTime.now().toIso8601String();
    final stub = SystemStats(
      cpuPercent: (DateTime.now().millisecond % 100).toDouble(),
      memUsedMb: 2048 + DateTime.now().second * 10,
      memTotalMb: 16384,
      diskUsedGb: 120.5,
      diskTotalGb: 500.0,
      netRxBytes: DateTime.now().millisecondsSinceEpoch % 1000000,
      netTxBytes: DateTime.now().millisecondsSinceEpoch % 500000,
      timestamp: now,
    );
    final newHistory = [...state.history, stub];
    if (newHistory.length > _historyMax) {
      newHistory.removeRange(0, newHistory.length - _historyMax);
    }
    state = state.copyWith(stats: stub, history: newHistory);
  }

  Future<void> refreshProcesses(String sessionId, {int limit = 20}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    // Stub: empty list until SSH wired.
    state = state.copyWith(processes: [], isLoading: false);
  }

  Future<void> sendSignal(String sessionId, int pid, String signal) async {
    const allowed = {'SIGTERM', 'SIGKILL', 'SIGUSR1', 'SIGUSR2'};
    if (!allowed.contains(signal)) {
      state = state.copyWith(error: 'Unsupported signal: $signal');
      return;
    }
    try {
      await bridge.monitorSendSignal(
        sessionId: sessionId,
        pid: pid,
        signal: signal,
        processName: '',
        expertMode: false,
      );
    } catch (_) {
      // Bridge unavailable — treat as sent locally for UX.
    }
    state = state.copyWith(clearError: true);
  }

  void _dispose() {
    _pollTimer?.cancel();
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final monitorProvider =
    NotifierProvider<MonitorNotifier, MonitorState>(MonitorNotifier.new);
