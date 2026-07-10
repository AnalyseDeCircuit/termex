/// User-tunable notification thresholds — persisted Riverpod state for
/// the Settings UI.
///
/// v0.79.55: relocated to `termex_shared` so the desktop SettingsPage can
/// drive the same provider as mobile (PC parity). Pure
/// SharedPreferences-backed Notifier — no mobile-only deps.
///
/// The pure threshold predicate (`shouldNotifyForPayload`) reads from a
/// non-Riverpod singleton (`NotificationThresholdConfig`) because it fires
/// from a sink callback outside the widget tree. A wrapper widget under
/// MobileShell ([NotificationThresholdsListener]) bridges this provider
/// into that singleton on every change.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_threshold.dart';

const _kPrefsKey = 'mobile.notification.thresholds.v1';

class NotificationSettingsNotifier extends Notifier<NotificationThresholds> {
  Timer? _saveTimer;

  @override
  NotificationThresholds build() {
    // Schedule an async load; the UI sees defaults for one frame then the
    // persisted snapshot if any.
    _loadInBackground();
    return NotificationThresholds.defaults;
  }

  Future<void> _loadInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = NotificationThresholds.fromJson(decoded);
      }
    } catch (_) {
      // Corrupt snapshot — keep defaults.
    }
  }

  void setSftpSuccessEnabled(bool enabled) {
    state = state.copyWith(sftpSuccessEnabled: enabled);
    _scheduleSave();
  }

  void setSizeBytes(int bytes) {
    if (bytes < 0) bytes = 0;
    state = state.copyWith(sizeBytes: bytes);
    _scheduleSave();
  }

  void setDurationMs(int ms) {
    if (ms < 0) ms = 0;
    state = state.copyWith(durationMs: ms);
    _scheduleSave();
  }

  void setUndoWindowSeconds(int seconds) {
    state =
        state.copyWith(undoWindowSeconds: seconds.clamp(0, 30));
    _scheduleSave();
  }

  void resetToDefaults() {
    state = NotificationThresholds.defaults;
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () {
      _saveTimer = null;
      // ignore: discarded_futures
      _persist(state);
    });
  }

  Future<void> _persist(NotificationThresholds snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Persistence is best-effort; in-memory state still drives the UI.
    }
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationThresholds>(
  NotificationSettingsNotifier.new,
);
