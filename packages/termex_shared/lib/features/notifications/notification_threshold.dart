/// Per-source rules deciding when a [TaskCompletionPayload] should trigger
/// an OS notification.
///
/// v0.79.55: relocated from `app/lib/mobile/` to `termex_shared` so the
/// desktop SettingsPage can render the same threshold UI as mobile —
/// PC parity for the user-tunable notification settings. The data + the
/// decision predicate are pure Dart (no mobile-only deps), so the move
/// is structural only.
///
/// History recording is **always** unconditional — these rules only gate
/// the "ping the user" path. Goal: avoid lock-screen spam from fast small
/// SFTP transfers without losing audit trail.
///
/// v0.79.31: thresholds are user-configurable through a Settings UI.
/// The pure `shouldNotifyForPayload` reads from [NotificationThresholdConfig]
/// — a global singleton kept in sync with a Riverpod provider by a wrapper
/// widget under MobileShell. Same pattern as `MobileLocalizer` (the
/// notifier callback fires outside the widget tree, so a static singleton
/// is the only abstraction that survives).
library;

import '../task/task_completion_sink.dart';

/// Snapshot of the user-tunable thresholds. Immutable — replaced wholesale
/// by [NotificationThresholdConfig.update] when the Settings UI saves.
///
/// v0.79.34: this bucket also carries [undoWindowSeconds] — strictly a
/// task-history UX preference, not a notification threshold. The shared
/// SharedPreferences-backed bucket keeps the persistence layer DRY; a
/// rename to a more generic "MobileUserPrefs" can land when a third
/// non-notification field arrives.
class NotificationThresholds {
  /// When false, SFTP success transfers never notify regardless of size /
  /// duration. Failures + cancellations still notify.
  final bool sftpSuccessEnabled;

  /// Minimum file size (bytes) at or above which an SFTP success notifies.
  /// `total >= sizeBytes` OR `duration >= durationMs` (see [NotificationThresholds.shouldNotifySftpSuccess]).
  final int sizeBytes;

  /// Minimum transfer duration (milliseconds) at or above which an SFTP
  /// success notifies.
  final int durationMs;

  /// v0.79.34: how long the delete / clear-all undo banner stays visible
  /// before the deletion becomes permanent. Range 0..30. 0 disables the
  /// undo window entirely (deletes commit instantly with no banner).
  final int undoWindowSeconds;

  const NotificationThresholds({
    this.sftpSuccessEnabled = true,
    this.sizeBytes = 1024 * 1024, // 1 MB
    this.durationMs = 3000, // 3 s
    this.undoWindowSeconds = 5,
  });

  /// v0.79.31 baseline. Used when the persisted snapshot is missing or
  /// corrupt, and as the starting state for the Settings UI.
  static const defaults = NotificationThresholds();

  bool shouldNotifySftpSuccess(int totalBytes, int durationMs) {
    if (!sftpSuccessEnabled) return false;
    return totalBytes >= sizeBytes || durationMs >= this.durationMs;
  }

  NotificationThresholds copyWith({
    bool? sftpSuccessEnabled,
    int? sizeBytes,
    int? durationMs,
    int? undoWindowSeconds,
  }) =>
      NotificationThresholds(
        sftpSuccessEnabled: sftpSuccessEnabled ?? this.sftpSuccessEnabled,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        durationMs: durationMs ?? this.durationMs,
        undoWindowSeconds: undoWindowSeconds ?? this.undoWindowSeconds,
      );

  Map<String, dynamic> toJson() => {
        'sftpSuccessEnabled': sftpSuccessEnabled,
        'sizeBytes': sizeBytes,
        'durationMs': durationMs,
        'undoWindowSeconds': undoWindowSeconds,
      };

  static NotificationThresholds fromJson(Map<String, dynamic> j) {
    final enabled = j['sftpSuccessEnabled'];
    final size = j['sizeBytes'];
    final duration = j['durationMs'];
    final undo = j['undoWindowSeconds'];
    return NotificationThresholds(
      sftpSuccessEnabled: enabled is bool ? enabled : true,
      sizeBytes: size is int ? size : defaults.sizeBytes,
      durationMs: duration is int ? duration : defaults.durationMs,
      undoWindowSeconds:
          undo is int ? undo.clamp(0, 30) : defaults.undoWindowSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationThresholds &&
      other.sftpSuccessEnabled == sftpSuccessEnabled &&
      other.sizeBytes == sizeBytes &&
      other.durationMs == durationMs &&
      other.undoWindowSeconds == undoWindowSeconds;

  @override
  int get hashCode => Object.hash(
        sftpSuccessEnabled,
        sizeBytes,
        durationMs,
        undoWindowSeconds,
      );
}

/// Global, mutable handle exposing the [NotificationThresholds] currently
/// in effect. Updated by the Riverpod provider listener; read by
/// [shouldNotifyForPayload] (which has no Ref).
class NotificationThresholdConfig {
  NotificationThresholdConfig._();

  static NotificationThresholds _current = NotificationThresholds.defaults;

  static NotificationThresholds get current => _current;

  /// Called from the Riverpod provider listener. Idempotent — replacing
  /// with an equal-valued snapshot is fine.
  static void update(NotificationThresholds thresholds) {
    _current = thresholds;
  }

  /// Test-only escape hatch — resets to defaults so each test starts
  /// from a known state.
  static void reset() {
    _current = NotificationThresholds.defaults;
  }
}

/// Threshold-based notify decision. Defaults to true; returns false only
/// when the source/payload matches a known "silence me" rule.
///
/// Current rules:
///   - Failures and cancellations always notify (user wants to know).
///   - Successful SFTP transfers are filtered by
///     [NotificationThresholdConfig.current.shouldNotifySftpSuccess].
///   - Unknown kinds default to notify=true (conservative).
bool shouldNotifyForPayload(TaskCompletionPayload payload) {
  if (!payload.success) return true;
  final kind = payload.kind;
  if (kind == null) return true;
  if (!kind.startsWith('sftp.')) return true;
  if (!kind.endsWith('.succeeded')) return true;
  final total = payload.data['totalBytes'];
  final durationMs = payload.data['durationMs'];
  if (total is! int || durationMs is! int) return true;
  return NotificationThresholdConfig.current
      .shouldNotifySftpSuccess(total, durationMs);
}
