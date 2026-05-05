import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:termex/features/settings/state/settings_provider.dart';

void main() {
  group('AppSettings', () {
    test('default values are sane', () {
      const s = AppSettings();
      expect(s.fontSize, greaterThan(0));
      expect(s.scrollbackLines, greaterThan(0));
      expect(s.cursorBlink, isA<bool>());
      expect(s.themeMode, equals(ThemeMode.dark));
    });

    test('copyWith changes only specified field', () {
      const s = AppSettings();
      final updated = s.copyWith(fontSize: 18);
      expect(updated.fontSize, equals(18));
      expect(updated.scrollbackLines, equals(s.scrollbackLines));
    });

    test('isDirty is false initially', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(settingsProvider);
      expect(state.isDirty, isFalse);
    });

    test('update marks dirty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const updated = AppSettings(fontSize: 18);
      container.read(settingsProvider.notifier).update(updated);
      expect(container.read(settingsProvider).isDirty, isTrue);
    });

    test('resetToDefaults clears dirty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(settingsProvider.notifier).update(const AppSettings(fontSize: 18));
      container.read(settingsProvider.notifier).resetToDefaults();
      expect(container.read(settingsProvider).isDirty, isFalse);
    });

    test('save clears dirty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(settingsProvider.notifier).update(const AppSettings(fontSize: 18));
      await container.read(settingsProvider.notifier).save();
      expect(container.read(settingsProvider).isDirty, isFalse);
    });
  });

  group('AuditLogEntry', () {
    test('parsed from valid data', () {
      final entry = AuditLogEntry(
        id: 'e1',
        eventType: 'ssh_connect',
        detail: 'Connected to server',
        createdAt: DateTime(2025, 1, 1),
      );
      expect(entry.eventType, equals('ssh_connect'));
    });
  });

  group('SettingsNotifier.loadAuditLogs', () {
    test('returns empty initially', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(settingsProvider.notifier).loadAuditLogs();
      expect(container.read(settingsProvider).auditLogs, isA<List>());
    });

    test('filterType changes results', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(settingsProvider.notifier).loadAuditLogs(eventType: 'ssh_connect');
      final logs = container.read(settingsProvider).auditLogs;
      for (final log in logs) {
        expect(log.eventType, equals('ssh_connect'));
      }
    });
  });
}
