/// Refcount-based wrapper around the Android foreground service.
///
/// Each `MobileTerminalPage` / `MobileSftpPage` calls [acquire] when it
/// opens an SSH session and [release] when it disposes. The first
/// `acquire` starts the foreground service; the last `release` stops
/// it. iOS doesn't have foreground services (the closest is a
/// short-lived `UIBackgroundTaskIdentifier`); the platform channel
/// simply has no handler registered there, so the swallowed
/// `MissingPluginException` makes the call a silent no-op.
library;

import 'package:flutter/services.dart' show MethodChannel;

class MobileBackgroundService {
  static const _channel = MethodChannel('termex/background');
  static int _refCount = 0;

  /// Increments the active-session refcount. Starts the Android
  /// foreground service when transitioning 0 → 1; on every subsequent
  /// `acquire` the call still goes through with the updated count so
  /// the foreground notification text stays accurate ("N active
  /// sessions"). Failures (no handler on iOS, denied permission on
  /// Android) are swallowed — we'd rather connect the session than
  /// abort over a notification side-effect.
  static Future<void> acquire() async {
    _refCount += 1;
    try {
      await _channel.invokeMethod<void>(
        'startSession',
        {'count': _refCount},
      );
    } catch (_) {}
  }

  /// Decrements the refcount; stops the foreground service when it
  /// hits 0, otherwise issues a refresh with the new count.
  static Future<void> release() async {
    if (_refCount == 0) return;
    _refCount -= 1;
    try {
      if (_refCount == 0) {
        await _channel.invokeMethod<void>('stopSession');
      } else {
        await _channel.invokeMethod<void>(
          'startSession',
          {'count': _refCount},
        );
      }
    } catch (_) {}
  }

  /// Android only: reports whether Termex is already on the
  /// battery-optimisation whitelist. Returns `false` on iOS (no such
  /// concept) and on platforms where the method-channel handler isn't
  /// wired, so call sites can use it as a "should I prompt?" gate
  /// without an explicit `Platform.isAndroid` check.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Android only: opens the system Settings page that lets the user
  /// add Termex to the battery-optimisation whitelist. Without this,
  /// aggressive OEMs (Xiaomi, Huawei, Oppo) may kill the foreground
  /// service after 5-10 minutes of background time, severing SSH
  /// sessions despite v0.79.3's foreground service. No-op on iOS.
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel
          .invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }
}
