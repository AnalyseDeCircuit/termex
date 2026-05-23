/// Local persistence for the manual-backup history list (P1.12).
///
/// Records the last [maxEntries] export attempts (success or failure) in
/// SharedPreferences as a single JSON array. Stored fully local — no FRB
/// round-trip — because the data is tied to one device's user actions, not
/// to anything in the encrypted database. The full cloud-scheduler that
/// will eventually displace this lives in v0.68.0 G1; until then this gives
/// users immediate visibility into their backup activity.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BackupStatus { success, failed }

class BackupRecord {
  final DateTime timestamp;
  final String path;
  final int? sizeBytes;
  final BackupStatus status;
  final String? error;

  const BackupRecord({
    required this.timestamp,
    required this.path,
    this.sizeBytes,
    required this.status,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        't': timestamp.toIso8601String(),
        'p': path,
        's': sizeBytes,
        'st': status.name,
        if (error != null) 'e': error,
      };

  static BackupRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ts = DateTime.tryParse(raw['t'] as String? ?? '');
    final path = raw['p'] as String?;
    if (ts == null || path == null) return null;
    final statusStr = raw['st'] as String? ?? 'success';
    return BackupRecord(
      timestamp: ts,
      path: path,
      sizeBytes: raw['s'] as int?,
      status: BackupStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => BackupStatus.success,
      ),
      error: raw['e'] as String?,
    );
  }
}

class BackupHistoryNotifier extends AsyncNotifier<List<BackupRecord>> {
  static const _key = 'termex.backup_history';
  static const int maxEntries = 20;

  @override
  Future<List<BackupRecord>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(BackupRecord.fromJson)
          .whereType<BackupRecord>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> record(BackupRecord entry) async {
    final current = state.valueOrNull ?? const <BackupRecord>[];
    final next = <BackupRecord>[entry, ...current].take(maxEntries).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next.map((r) => r.toJson()).toList()));
    state = AsyncData(next);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData([]);
  }
}

final backupHistoryProvider =
    AsyncNotifierProvider<BackupHistoryNotifier, List<BackupRecord>>(
  BackupHistoryNotifier.new,
);
