import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/api.dart' as bridge;
import 'package:termex_bridge/models.dart' as bridge_models;

// ─── Models ───────────────────────────────────────────────────────────────────

enum LocalAiStatus { stopped, starting, running, error }

class LocalModel {
  final String id;
  final String name;
  final String description;
  final int sizeBytes;
  final String sizeLabel;
  final String quantization;
  final bool isDownloaded;
  final String? localPath;
  /// Download progress 0.0–1.0, null when not downloading.
  ///
  /// v0.79.58: when the server doesn't expose `Content-Length` (e.g.
  /// HuggingFace CDN replies with `Transfer-Encoding: chunked`), the
  /// Rust downloader reports `(downloaded, 0)`. In that case the
  /// fraction is unknown — [downloadProgress] stays at `0.0` and the
  /// UI consults [downloadedBytes] / [totalBytesKnown] instead to
  /// render an indeterminate spinner with a live byte counter. Without
  /// this users on iOS simulator saw a stuck "0 B / 4.5 GB (0.0%)"
  /// because polling kept skipping updates when `total == 0`.
  final double? downloadProgress;
  /// v0.79.58: bytes downloaded so far, even when total is unknown.
  /// Drives the byte-counter label under the progress bar.
  final int? downloadedBytes;
  /// v0.79.58: `false` when the server isn't advertising a total
  /// (chunked transfer / no Content-Length). UI renders indeterminate.
  final bool totalBytesKnown;

  const LocalModel({
    required this.id,
    required this.name,
    required this.description,
    required this.sizeBytes,
    required this.sizeLabel,
    required this.quantization,
    this.isDownloaded = false,
    this.localPath,
    this.downloadProgress,
    this.downloadedBytes,
    this.totalBytesKnown = true,
  });

  LocalModel copyWith({
    bool? isDownloaded,
    String? localPath,
    double? downloadProgress,
    int? downloadedBytes,
    bool? totalBytesKnown,
    bool clearProgress = false,
  }) =>
      LocalModel(
        id: id,
        name: name,
        description: description,
        sizeBytes: sizeBytes,
        sizeLabel: sizeLabel,
        quantization: quantization,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        localPath: localPath ?? this.localPath,
        downloadProgress: clearProgress ? null : (downloadProgress ?? this.downloadProgress),
        downloadedBytes: clearProgress ? null : (downloadedBytes ?? this.downloadedBytes),
        totalBytesKnown:
            clearProgress ? true : (totalBytesKnown ?? this.totalBytesKnown),
      );
}

// ─── State ────────────────────────────────────────────────────────────────────

class LocalAiState {
  final LocalAiStatus status;
  final String? loadedModelId;
  final int? memoryMb;
  final List<LocalModel> models;
  final String? errorMessage;

  const LocalAiState({
    this.status = LocalAiStatus.stopped,
    this.loadedModelId,
    this.memoryMb,
    this.models = const [],
    this.errorMessage,
  });

  bool get isRunning => status == LocalAiStatus.running;
  bool get isStarting => status == LocalAiStatus.starting;

  LocalAiState copyWith({
    LocalAiStatus? status,
    String? loadedModelId,
    int? memoryMb,
    List<LocalModel>? models,
    String? errorMessage,
    bool clearError = false,
    bool clearLoadedModel = false,
    bool clearMemory = false,
  }) =>
      LocalAiState(
        status: status ?? this.status,
        loadedModelId:
            clearLoadedModel ? null : (loadedModelId ?? this.loadedModelId),
        memoryMb: clearMemory ? null : (memoryMb ?? this.memoryMb),
        models: models ?? this.models,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

// ─── Defaults (shown when the bridge is unavailable) ──────────────────────────

const List<LocalModel> _defaultCatalog = [
  LocalModel(
    id: 'llama-3-8b',
    name: 'Llama 3 8B',
    description: 'General-purpose 8B parameter model (Meta)',
    sizeBytes: 4500000000,
    sizeLabel: '4.5 GB',
    quantization: 'Q4_K_M',
    isDownloaded: false,
  ),
  LocalModel(
    id: 'qwen-2-7b',
    name: 'Qwen 2 7B',
    description: 'Multilingual 7B parameter model (Alibaba)',
    sizeBytes: 4200000000,
    sizeLabel: '4.2 GB',
    quantization: 'Q4_K_M',
    isDownloaded: false,
  ),
];

// ─── Notifier ────────────────────────────────────────────────────────────────

class LocalAiNotifier extends Notifier<LocalAiState> {
  Timer? _healthTimer;

  @override
  LocalAiState build() {
    ref.onDispose(_stopPolling);
    // v0.79.65: `.catchError` is mandatory on the fire-and-forget
    // `_loadModels` future — without it, an FRB `session channel closed`
    // raised while iterating the catalog (notably when the user
    // navigates away mid-load on iOS) becomes an unhandled exception.
    Future.microtask(_loadModels).catchError((_) {});
    return const LocalAiState(models: _defaultCatalog);
  }

  Future<void> _loadModels() async {
    try {
      final remote = await bridge.localAiListModels();
      state = state.copyWith(
        models: remote
            .map((m) => LocalModel(
                  id: m.id,
                  name: m.name,
                  description: m.description,
                  sizeBytes: m.sizeBytes.toInt(),
                  sizeLabel: m.sizeLabel,
                  quantization: m.quantization,
                  isDownloaded: m.isDownloaded,
                ))
            .toList(),
      );
    } catch (_) {
      // Bridge unavailable — show curated default catalog.
      state = state.copyWith(models: _defaultCatalog);
    }
  }

  Future<void> startServer(String modelId) async {
    state = state.copyWith(status: LocalAiStatus.starting, clearError: true);
    try {
      await bridge.localAiStart(modelId: modelId, port: 8080);
    } catch (_) {
      // Bridge unavailable — enter running state optimistically; real health
      // checks will reconcile once the bridge comes online.
    }
    state = state.copyWith(
      status: LocalAiStatus.running,
      loadedModelId: modelId,
    );
    _startPolling();
  }

  Future<void> stopServer() async {
    _stopPolling();
    try {
      await bridge.localAiStop();
    } catch (_) {}
    state = state.copyWith(
      status: LocalAiStatus.stopped,
      clearLoadedModel: true,
      clearMemory: true,
    );
  }

  Future<void> downloadModel(String modelId) async {
    // Seed with `downloadedBytes: 0` + `totalBytesKnown: false` so the
    // UI immediately switches into "preparing / connecting" mode rather
    // than rendering a stuck "0% of 4.5 GB". As soon as the first poll
    // tick arrives with real bytes the row flips into determinate
    // (with bar) or indeterminate (with byte counter) accordingly.
    _updateModel(
      modelId,
      (m) => m.copyWith(
        downloadProgress: 0.0,
        downloadedBytes: 0,
        totalBytesKnown: false,
      ),
    );
    // v0.79.58: also track `downloaded` even when `total == 0` so the
    // UI can render indeterminate progress with a live byte counter.
    // Pre-v0.79.58 the polling skipped any tick where `total <= 0`,
    // which left iOS simulator users staring at "0 B / 4.5 GB (0.0%)"
    // whenever HF's CDN returned `Transfer-Encoding: chunked`.
    final progressTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) async {
      try {
        final p = await bridge.localAiDownloadProgress(modelId: modelId);
        if (p == null) return;
        final total = p.total.toInt();
        final downloaded = p.downloaded.toInt();
        if (total > 0) {
          final ratio = (downloaded / total).clamp(0.0, 1.0);
          _updateModel(
            modelId,
            (m) => m.copyWith(
              downloadProgress: ratio,
              downloadedBytes: downloaded,
              totalBytesKnown: true,
            ),
          );
        } else {
          // Total unknown — keep UI in indeterminate mode but surface
          // the live byte counter so the user sees the download is
          // actually progressing.
          _updateModel(
            modelId,
            (m) => m.copyWith(
              downloadProgress: 0.0,
              downloadedBytes: downloaded,
              totalBytesKnown: false,
            ),
          );
        }
      } catch (_) {
        // Polling is best-effort; ignore transient errors.
      }
    });
    try {
      await bridge.localAiDownloadModel(modelId: modelId);
      _updateModel(
        modelId,
        (m) => m.copyWith(isDownloaded: true, clearProgress: true),
      );
    } catch (e) {
      _updateModel(modelId, (m) => m.copyWith(clearProgress: true));
      state = state.copyWith(errorMessage: _friendlyDownloadError(e));
    } finally {
      progressTimer.cancel();
    }
  }

  /// v0.79.65: map FRB internal errors to user-friendly text. The most
  /// common one we surface is `session channel closed: <uuid>`, which
  /// fires when the Rust download task is cancelled / panics / the
  /// network drops mid-stream. The raw UUID-laden message is useless
  /// to the user.
  static String _friendlyDownloadError(Object e) {
    final raw = e.toString();
    if (raw.contains('session channel closed') ||
        raw.contains('Download cancelled')) {
      return 'Download interrupted. Tap Download again to retry; partial bytes are kept on disk and resumed.';
    }
    return raw;
  }

  Future<void> deleteModel(String modelId) async {
    try {
      await bridge.localAiDeleteModel(modelId: modelId);
    } catch (_) {}
    _updateModel(modelId, (m) => m.copyWith(isDownloaded: false));
  }

  void cancelDownload(String modelId) {
    // v0.79.65: the bridge call returns a `Future<void>` even though the
    // Rust function is synchronous (FRB v2 wraps every callable in
    // `Future`). A bare `try/catch` only catches sync throws — any
    // async error (most notably `session channel closed: <uuid>` when
    // the download future is mid-cancel) became an unhandled exception
    // that surfaced as a red error overlay in widget tests / debug
    // mode. Use `.then((_) {}, onError: (_) {})` to swallow both
    // success and failure asynchronously without awaiting (we can't
    // await in this `void` method without bubbling the await up).
    bridge
        .localAiCancelDownload(modelId: modelId)
        .then((_) {}, onError: (_) {});
    _updateModel(modelId, (m) => m.copyWith(clearProgress: true));
  }

  void _updateModel(String modelId, LocalModel Function(LocalModel) fn) {
    final updated = state.models.map((m) => m.id == modelId ? fn(m) : m).toList();
    state = state.copyWith(models: updated);
  }

  void _startPolling() {
    _healthTimer?.cancel();
    // v0.79.65: wrap `_pollHealth` Future with `.catchError` so any
    // residual error after its internal try/catch (e.g. state mutation
    // race) doesn't surface as an unhandled exception. Timer.periodic
    // accepts `void Function(Timer)`; the async return value is
    // discarded, so we attach the swallow here at the call site.
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollHealth().catchError((_) {});
    });
  }

  void _stopPolling() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  Future<void> _pollHealth() async {
    try {
      final h = await bridge.localAiHealth();
      state = state.copyWith(
        status: switch (h.status) {
          bridge_models.LocalAiStatus.stopped => LocalAiStatus.stopped,
          bridge_models.LocalAiStatus.starting => LocalAiStatus.starting,
          bridge_models.LocalAiStatus.running => LocalAiStatus.running,
          bridge_models.LocalAiStatus.error => LocalAiStatus.error,
        },
        loadedModelId: h.loadedModel,
        memoryMb: h.memoryMb?.toInt(),
      );
    } catch (_) {
      // health failure — leave current state
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final localAiProvider =
    NotifierProvider<LocalAiNotifier, LocalAiState>(LocalAiNotifier.new);
