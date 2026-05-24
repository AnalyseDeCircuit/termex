/// View-model mirrors of the v0.74.2 handoff DTOs in
/// `termex_core::handoff` + the wire-level DeviceWireDto. Kept
/// independent of FRB so widgets test without any bridge wiring.
library;

enum DevicePlatformVM {
  ios,
  android,
  macos,
  linux,
  windows,
  unknown;

  String get displayName => switch (this) {
        DevicePlatformVM.ios => 'iOS',
        DevicePlatformVM.android => 'Android',
        DevicePlatformVM.macos => 'macOS',
        DevicePlatformVM.linux => 'Linux',
        DevicePlatformVM.windows => 'Windows',
        DevicePlatformVM.unknown => 'Other',
      };

  bool get isMobile =>
      this == DevicePlatformVM.ios || this == DevicePlatformVM.android;

  static DevicePlatformVM parse(String s) => switch (s) {
        'ios' => DevicePlatformVM.ios,
        'android' => DevicePlatformVM.android,
        'macos' => DevicePlatformVM.macos,
        'linux' => DevicePlatformVM.linux,
        'windows' => DevicePlatformVM.windows,
        _ => DevicePlatformVM.unknown,
      };
}

/// A device the user has previously connected from.
class DeviceVM {
  final String id;
  final String name;
  final DevicePlatformVM platform;
  final DateTime lastSeenAt;
  /// True when this device is the one currently rendering the UI.
  final bool isSelf;
  /// True when the device's WS connection is currently open.
  final bool isOnline;
  const DeviceVM({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastSeenAt,
    required this.isSelf,
    required this.isOnline,
  });

  /// "5m ago" / "2h ago" / "3d ago" — short, mobile-friendly.
  /// Anchored on `now` so callers can pass a stable reference for
  /// deterministic tests.
  String lastSeenHuman({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(lastSeenAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

/// Outcome of a Send-to-device delivery returned by the daemon.
enum DeliveryOutcomeVM {
  ws,
  fcm,
  queued,
  unknownTarget;

  String get hintLabel => switch (this) {
        DeliveryOutcomeVM.ws => 'Delivered',
        DeliveryOutcomeVM.fcm => 'Pushed via FCM',
        DeliveryOutcomeVM.queued => 'Queued (device offline)',
        DeliveryOutcomeVM.unknownTarget => 'Unknown device',
      };

  static DeliveryOutcomeVM parse(String s) => switch (s) {
        'ws' => DeliveryOutcomeVM.ws,
        'fcm' => DeliveryOutcomeVM.fcm,
        'queued' => DeliveryOutcomeVM.queued,
        _ => DeliveryOutcomeVM.unknownTarget,
      };
}
