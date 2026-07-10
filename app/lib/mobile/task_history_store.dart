/// Disk-backed persistence for [TaskEventBus] (v0.79.26).
///
/// Saves the bus's `latestSnapshot` to a single SharedPreferences key as a
/// JSON envelope. Cold-starts rehydrate so the user's task history
/// survives across app launches (otherwise every restart would lose the
/// list and notifications would feel like a phantom — see v0.79.24).
///
/// Retention: bounded at [kMaxEntries] = 200 events. Older ones are
/// trimmed by `occurredAt` ascending so the most recent ones stay.
/// 200 covers weeks of light usage and a few days of heavy SFTP / AI
/// activity; the trim happens at save time so disk reads are O(n) in
/// the kept set, not the historical accumulation.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'task_event_bus.dart';

/// SharedPreferences key — versioned so migrations can ignore stale
/// payloads without false positives in the future.
const _kPrefsKey = 'mobile.task_history.snapshot_v1';
const int kMaxEntries = 200;

class TaskHistoryStore implements TaskHistoryPersistence {
  TaskHistoryStore._(this._prefs);

  static Future<TaskHistoryStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return TaskHistoryStore._(prefs);
  }

  final SharedPreferences _prefs;

  @override
  Future<Map<String, TaskEvent>> load() async {
    final raw = _prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final entries = decoded['entries'];
      if (entries is! List) return {};
      final out = <String, TaskEvent>{};
      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) continue;
        final event = TaskEvent.fromJson(entry);
        if (event == null) continue;
        out[event.taskId] = event;
      }
      return out;
    } catch (e, st) {
      debugPrint('TaskHistoryStore.load failed: $e\n$st');
      return {};
    }
  }

  @override
  Future<void> save(Map<String, TaskEvent> snapshot) async {
    try {
      // Trim by occurredAt ASC; keep the most recent [kMaxEntries].
      final all = snapshot.values.toList()
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      final kept = all.length > kMaxEntries
          ? all.sublist(all.length - kMaxEntries)
          : all;
      final payload = {
        'version': 1,
        'entries': kept.map((e) => e.toJson()).toList(),
      };
      final encoded = jsonEncode(payload);
      await _prefs.setString(_kPrefsKey, encoded);
    } catch (e, st) {
      debugPrint('TaskHistoryStore.save failed: $e\n$st');
    }
  }

  /// Test affordance — clears the on-disk snapshot. Production callers
  /// should not reach for this (the bus handles trimming).
  @visibleForTesting
  Future<void> clear() async {
    await _prefs.remove(_kPrefsKey);
  }
}
