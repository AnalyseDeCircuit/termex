/// One-time prompt that suggests the user add Termex to the Android
/// battery-optimisation whitelist.
///
/// Fired by `MobileTerminalPage` / `MobileSftpPage` immediately after the
/// first successful SSH session opens — the moment the foreground service
/// becomes meaningful. Skipped when:
///   - the platform is not Android (iOS has no equivalent setting)
///   - Termex is already whitelisted
///   - the user has previously seen the prompt (regardless of their answer)
///
/// The dismissal flag lives in shared_preferences under `_kFlagKey` and is
/// cleared by uninstall/reinstall, which is the same lifecycle as battery
/// optimisation state itself, so a fresh install gets a fresh nag.
library;

import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:termex_shared/widgets/dialog.dart';

import 'background_service.dart';

class MobileBatteryNag {
  static const _kFlagKey = 'mobile.battery_nag.shown_v1';

  /// Shows the prompt if conditions are met; otherwise a no-op. Pass the
  /// [BuildContext] of a widget that's still mounted — typically right
  /// after a `setState` in a `_openSession()` callback.
  static Future<void> maybeShow(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kFlagKey) ?? false) return;

    final whitelisted =
        await MobileBackgroundService.isIgnoringBatteryOptimizations();
    if (whitelisted) {
      // Already on the whitelist — flip the flag so we don't poll the
      // platform channel on every future connect.
      await prefs.setBool(_kFlagKey, true);
      return;
    }

    if (!context.mounted) return;

    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Keep sessions alive in background?',
      message:
          'Some Android manufacturers (Xiaomi, Huawei, Oppo) close apps after '
          'a few minutes in the background even with a foreground notification. '
          'Tap "Open settings" to add Termex to the battery-optimisation '
          'whitelist so SSH sessions survive longer. You can also do this '
          'anytime from Settings → Background keep-alive.',
      confirmLabel: 'Open settings',
      cancelLabel: 'Not now',
    );

    if (confirmed == true) {
      await MobileBackgroundService.requestIgnoreBatteryOptimizations();
    }

    // Persist the "already shown" state regardless of which button the
    // user tapped — we only want to ask once per install. Settings tab
    // (v0.79.5) remains the on-demand entry point for later.
    await prefs.setBool(_kFlagKey, true);
  }
}
