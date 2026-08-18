/// Per-session recording state.
///
/// Mirrors the Tauri build's `recordingStore.activeRecordings` map: the UI
/// needs to know, for one session, whether a recording is running and when it
/// started so it can show elapsed time.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/api.dart' as bridge;

class RecordingStatus {
  final bool active;
  final String? recordingId;
  final DateTime? startedAt;
  final String? errorMessage;

  const RecordingStatus({
    this.active = false,
    this.recordingId,
    this.startedAt,
    this.errorMessage,
  });

  /// Time since the recording began, or zero when idle.
  Duration get elapsed => startedAt == null
      ? Duration.zero
      : DateTime.now().difference(startedAt!);
}

class RecordingNotifier extends FamilyNotifier<RecordingStatus, String> {
  @override
  RecordingStatus build(String sessionId) => const RecordingStatus();

  /// Begins capturing this session's terminal output.
  ///
  /// [cols]/[rows] go into the asciicast header — a player needs the real
  /// geometry to lay the frames out.
  Future<void> start({
    required String serverId,
    required String serverName,
    int cols = 80,
    int rows = 24,
    String? title,
    int maxRecordingMb = 0,
    /// Set by the connect path when the server is flagged for auto-record;
    /// the list badges those entries AUTO.
    bool autoRecorded = false,
    /// The terminal's current contents, written as the recording's first
    /// frame so playback does not open on a black screen.
    String? initialScreen,
  }) async {
    if (state.active) return;
    try {
      final id = await bridge.recordingStart(
        sessionId: arg,
        serverId: serverId,
        serverName: serverName,
        cols: cols,
        rows: rows,
        title: title,
        maxRecordingMb: maxRecordingMb,
        autoRecorded: autoRecorded,
        initialScreen: initialScreen,
      );
      state = RecordingStatus(
        active: true,
        recordingId: id,
        startedAt: DateTime.now(),
      );
    } catch (e) {
      state = RecordingStatus(errorMessage: e.toString());
    }
  }

  /// Stops and flushes the `.cast` file.
  Future<void> stop() async {
    if (!state.active) return;
    try {
      await bridge.recordingStop(sessionId: arg);
      state = const RecordingStatus();
    } catch (e) {
      // Clear the active flag regardless: leaving the UI showing REC after a
      // failed stop would misreport what the backend is doing.
      state = RecordingStatus(errorMessage: e.toString());
    }
  }

  /// Reconciles with the backend — the widget can be rebuilt or the tab
  /// reopened while a recording is still running.
  Future<void> refresh() async {
    try {
      final active = await bridge.recordingIsActive(sessionId: arg);
      if (active == state.active) return;
      state = active
          ? RecordingStatus(active: true, startedAt: DateTime.now())
          : const RecordingStatus();
    } catch (_) {
      // Reconciling is best-effort: this runs from initState, and a failure
      // here (bridge not up yet, session already gone) must leave the control
      // usable rather than take the terminal chrome down with it.
    }
  }
}

final recordingProvider =
    NotifierProvider.family<RecordingNotifier, RecordingStatus, String>(
        RecordingNotifier.new);
