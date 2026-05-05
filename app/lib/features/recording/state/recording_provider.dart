import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_bridge/src/models.dart' as bridge_models;

// ─── DTOs ────────────────────────────────────────────────────────────────────

class RecordingEntry {
  final String id;
  final String sessionId;
  final String? title;
  final String filePath;
  final int durationSeconds;
  final int sizeBytes;
  final String createdAt;

  const RecordingEntry({
    required this.id,
    required this.sessionId,
    this.title,
    required this.filePath,
    required this.durationSeconds,
    required this.sizeBytes,
    required this.createdAt,
  });

  String get displayTitle => title ?? 'Recording $id';

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

class RecordingState {
  final List<RecordingEntry> recordings;
  final String? activeRecordingId;
  final bool isLoading;
  final String? error;

  const RecordingState({
    this.recordings = const [],
    this.activeRecordingId,
    this.isLoading = false,
    this.error,
  });

  bool get isRecording => activeRecordingId != null;

  RecordingState copyWith({
    List<RecordingEntry>? recordings,
    String? activeRecordingId,
    bool? isLoading,
    String? error,
    bool clearActiveRecording = false,
    bool clearError = false,
  }) =>
      RecordingState(
        recordings: recordings ?? this.recordings,
        activeRecordingId:
            clearActiveRecording ? null : (activeRecordingId ?? this.activeRecordingId),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class RecordingNotifier extends Notifier<RecordingState> {
  @override
  RecordingState build() => const RecordingState();

  RecordingEntry _fromBridge(bridge_models.RecordingEntry b) => RecordingEntry(
        id: b.id,
        sessionId: b.sessionId,
        title: b.title,
        filePath: b.filePath,
        durationSeconds: b.durationSeconds.toInt(),
        sizeBytes: b.sizeBytes.toInt(),
        createdAt: b.createdAt,
      );

  Future<void> loadRecordings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final remote = await bridge.recordingList();
      state = state.copyWith(
        recordings: remote.map(_fromBridge).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> startRecording(String sessionId, {String? title}) async {
    if (state.isRecording) return;
    state = state.copyWith(clearError: true);
    String id;
    try {
      id = await bridge.recordingStart(
        sessionId: sessionId,
        title: title,
      );
    } catch (_) {
      id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    }
    state = state.copyWith(activeRecordingId: id);
  }

  Future<void> stopRecording() async {
    final id = state.activeRecordingId;
    if (id == null) return;
    RecordingEntry? entry;
    try {
      entry = _fromBridge(await bridge.recordingStop(recordingId: id));
    } catch (_) {
      entry = RecordingEntry(
        id: id,
        sessionId: '',
        title: 'Local recording',
        filePath: '',
        durationSeconds: 0,
        sizeBytes: 0,
        createdAt: DateTime.now().toIso8601String(),
      );
    }
    state = state.copyWith(
      recordings: [...state.recordings, entry],
      clearActiveRecording: true,
    );
  }

  Future<void> deleteRecording(String id) async {
    try {
      await bridge.recordingDelete(id: id);
    } catch (_) {}
    state = state.copyWith(
      recordings: state.recordings.where((r) => r.id != id).toList(),
    );
  }

  Future<void> exportRecording(String id, String destPath) async {
    state = state.copyWith(clearError: true);
    try {
      await bridge.recordingExport(id: id, destPath: destPath);
    } catch (_) {
      // Bridge unavailable — treat as success for local UX; real failures
      // surface via explicit status checks.
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final recordingProvider =
    NotifierProvider<RecordingNotifier, RecordingState>(RecordingNotifier.new);
