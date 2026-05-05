import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_bridge/src/models.dart' as bridge_models;

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
  final double? downloadProgress;

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
  });

  LocalModel copyWith({
    bool? isDownloaded,
    String? localPath,
    double? downloadProgress,
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
    Future.microtask(_loadModels);
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
    _updateModel(modelId, (m) => m.copyWith(downloadProgress: 0.0));
    try {
      await bridge.localAiDownloadModel(modelId: modelId);
      _updateModel(
        modelId,
        (m) => m.copyWith(isDownloaded: true, clearProgress: true),
      );
    } catch (e) {
      _updateModel(modelId, (m) => m.copyWith(clearProgress: true));
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteModel(String modelId) async {
    try {
      await bridge.localAiDeleteModel(modelId: modelId);
    } catch (_) {}
    _updateModel(modelId, (m) => m.copyWith(isDownloaded: false));
  }

  void cancelDownload(String modelId) {
    try {
      bridge.localAiCancelDownload(modelId: modelId);
    } catch (_) {}
    _updateModel(modelId, (m) => m.copyWith(clearProgress: true));
  }

  void _updateModel(String modelId, LocalModel Function(LocalModel) fn) {
    final updated = state.models.map((m) => m.id == modelId ? fn(m) : m).toList();
    state = state.copyWith(models: updated);
  }

  void _startPolling() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollHealth());
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
