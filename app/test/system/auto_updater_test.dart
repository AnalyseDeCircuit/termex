import 'package:flutter_test/flutter_test.dart';

import 'package:termex/system/auto_updater.dart';

void main() {
  group('FakeAutoUpdater state machine', () {
    test('idle → checking → available on check', () async {
      final u = FakeAutoUpdater()
        ..onCheck = () async => const UpdateStatus.available('0.49.0');
      final events = <UpdateStage>[];
      u.statusStream().listen((s) => events.add(s.stage));

      final result = await u.checkForUpdate();

      await Future<void>.delayed(Duration.zero);
      expect(result, isTrue);
      expect(events, [UpdateStage.checking, UpdateStage.available]);
      expect(u.current.newVersion, equals('0.49.0'));
      u.dispose();
    });

    test('check returns false when no update', () async {
      final u = FakeAutoUpdater()
        ..onCheck = () async => const UpdateStatus.idle();

      final result = await u.checkForUpdate();

      expect(result, isFalse);
      expect(u.current.stage, equals(UpdateStage.idle));
      u.dispose();
    });

    test('check emits failed on exception', () async {
      final u = FakeAutoUpdater()
        ..onCheck = () async => throw Exception('network');

      final result = await u.checkForUpdate();

      expect(result, isFalse);
      expect(u.current.stage, equals(UpdateStage.failed));
      expect(u.current.error, contains('network'));
      u.dispose();
    });

    test('downloadUpdate requires available stage', () async {
      final u = FakeAutoUpdater();
      expect(() => u.downloadUpdate(), throwsStateError);
      u.dispose();
    });

    test('downloadUpdate emits progress then ready', () async {
      final u = FakeAutoUpdater()
        ..onCheck = (() async => const UpdateStatus.available('0.49.0'))
        ..onDownload = (onProgress) async {
          onProgress(0.25);
          onProgress(0.75);
        };
      await u.checkForUpdate();

      final progresses = <double>[];
      u.statusStream().listen((s) {
        if (s.stage == UpdateStage.downloading && s.progress != null) {
          progresses.add(s.progress!);
        }
      });
      await u.downloadUpdate();

      await Future<void>.delayed(Duration.zero);
      expect(progresses, containsAllInOrder(<double>[0.0, 0.25, 0.75]));
      expect(u.current.stage, equals(UpdateStage.ready));
      expect(u.current.newVersion, equals('0.49.0'));
      u.dispose();
    });

    test('applyUpdate requires ready stage', () async {
      final u = FakeAutoUpdater();
      expect(() => u.applyUpdate(), throwsStateError);
      u.dispose();
    });

    test('applyUpdate invokes onApply', () async {
      var called = false;
      final u = FakeAutoUpdater()
        ..onCheck = (() async => const UpdateStatus.available('0.49.0'))
        ..onDownload = (_) async {}
        ..onApply = () async {
          called = true;
        };
      await u.checkForUpdate();
      await u.downloadUpdate();
      await u.applyUpdate();

      expect(called, isTrue);
      u.dispose();
    });
  });

  group('UpdateStatus constructors', () {
    test('named ctors set stage correctly', () {
      expect(const UpdateStatus.idle().stage, UpdateStage.idle);
      expect(const UpdateStatus.checking().stage, UpdateStage.checking);
      expect(const UpdateStatus.available('1.0.0').stage, UpdateStage.available);
      expect(const UpdateStatus.downloading(0.5).stage, UpdateStage.downloading);
      expect(const UpdateStatus.ready('1.0.0').stage, UpdateStage.ready);
      expect(const UpdateStatus.failed('boom').stage, UpdateStage.failed);
    });
  });
}
