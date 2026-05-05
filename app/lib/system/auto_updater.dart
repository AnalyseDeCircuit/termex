/// Auto-update abstraction (v0.49 spec §5.2).
///
/// Platform implementations live in `auto_updater_macos.dart`,
/// `auto_updater_windows.dart`, `auto_updater_linux.dart`.  Rust side
/// (`termex-flutter-bridge/src/api/update.rs`) handles appcast polling and
/// version comparison.
library;

import 'dart:async';

enum UpdateStage {
  idle,
  checking,
  available,
  downloading,
  ready,
  failed,
}

class UpdateStatus {
  final UpdateStage stage;
  final String? newVersion;
  final String? changelogUrl;
  final double? progress;
  final String? error;

  const UpdateStatus({
    required this.stage,
    this.newVersion,
    this.changelogUrl,
    this.progress,
    this.error,
  });

  const UpdateStatus.idle() : this(stage: UpdateStage.idle);
  const UpdateStatus.checking() : this(stage: UpdateStage.checking);
  const UpdateStatus.available(String version, {String? changelogUrl})
      : this(
          stage: UpdateStage.available,
          newVersion: version,
          changelogUrl: changelogUrl,
        );
  const UpdateStatus.downloading(double progress, {String? newVersion})
      : this(
          stage: UpdateStage.downloading,
          progress: progress,
          newVersion: newVersion,
        );
  const UpdateStatus.ready(String version) : this(stage: UpdateStage.ready, newVersion: version);
  const UpdateStatus.failed(String error) : this(stage: UpdateStage.failed, error: error);

  @override
  String toString() => 'UpdateStatus($stage v=$newVersion p=$progress e=$error)';
}

abstract class AutoUpdater {
  Stream<UpdateStatus> statusStream();

  Future<bool> checkForUpdate();

  Future<void> downloadUpdate();

  Future<void> applyUpdate();

  void dispose();
}

/// In-memory implementation used for tests and as the base class for the
/// three platform implementations.  Emits status transitions on a broadcast
/// stream and exposes hooks to drive the state machine deterministically.
class FakeAutoUpdater implements AutoUpdater {
  final _controller = StreamController<UpdateStatus>.broadcast();
  UpdateStatus _current = const UpdateStatus.idle();

  /// Override points for subclasses / tests.
  Future<UpdateStatus> Function()? onCheck;
  Future<void> Function(void Function(double) onProgress)? onDownload;
  Future<void> Function()? onApply;

  UpdateStatus get current => _current;

  @override
  Stream<UpdateStatus> statusStream() => _controller.stream;

  void _emit(UpdateStatus status) {
    _current = status;
    _controller.add(status);
  }

  @override
  Future<bool> checkForUpdate() async {
    _emit(const UpdateStatus.checking());
    try {
      final result = onCheck != null
          ? await onCheck!()
          : const UpdateStatus.idle();
      _emit(result);
      return result.stage == UpdateStage.available;
    } catch (e) {
      _emit(UpdateStatus.failed(e.toString()));
      return false;
    }
  }

  @override
  Future<void> downloadUpdate() async {
    if (_current.stage != UpdateStage.available) {
      throw StateError('no update available to download (stage=${_current.stage})');
    }
    final version = _current.newVersion;
    _emit(UpdateStatus.downloading(0.0, newVersion: version));
    try {
      if (onDownload != null) {
        await onDownload!((p) => _emit(UpdateStatus.downloading(p, newVersion: version)));
      }
      _emit(UpdateStatus.ready(version ?? ''));
    } catch (e) {
      _emit(UpdateStatus.failed(e.toString()));
    }
  }

  @override
  Future<void> applyUpdate() async {
    if (_current.stage != UpdateStage.ready) {
      throw StateError('update not ready (stage=${_current.stage})');
    }
    if (onApply != null) await onApply!();
  }

  @override
  void dispose() => _controller.close();
}
