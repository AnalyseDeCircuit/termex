/// Unit tests for [shouldNotifyForPayload] (v0.79.29) + user-tunable
/// [NotificationThresholdConfig] (v0.79.31).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:termex/mobile/notification_threshold.dart';
import 'package:termex_shared/features/task/task_completion_sink.dart';

void _resetConfig() {
  NotificationThresholdConfig.reset();
}

TaskCompletionPayload _sftpUploadSucceeded({
  required int totalBytes,
  required int durationMs,
}) =>
    TaskCompletionPayload(
      taskId: 't',
      title: 'fallback',
      summary: 'fallback',
      success: true,
      kind: 'sftp.upload.succeeded',
      data: {
        'fileName': 'foo.tar.gz',
        'totalBytes': totalBytes,
        'durationMs': durationMs,
      },
    );

void main() {
  setUp(_resetConfig);
  tearDownAll(_resetConfig);

  group('shouldNotifyForPayload — SFTP successes', () {
    test('large file (10 MB, 8 s) notifies', () {
      expect(
        shouldNotifyForPayload(
          _sftpUploadSucceeded(totalBytes: 10 * 1024 * 1024, durationMs: 8000),
        ),
        isTrue,
      );
    });

    test('sub-MB AND sub-3s success is silenced', () {
      expect(
        shouldNotifyForPayload(
          _sftpUploadSucceeded(totalBytes: 512 * 1024, durationMs: 800),
        ),
        isFalse,
      );
    });

    test('sub-MB but long (5 s) still notifies', () {
      expect(
        shouldNotifyForPayload(
          _sftpUploadSucceeded(totalBytes: 512 * 1024, durationMs: 5000),
        ),
        isTrue,
      );
    });

    test('over-MB but fast still notifies', () {
      expect(
        shouldNotifyForPayload(
          _sftpUploadSucceeded(totalBytes: 4 * 1024 * 1024, durationMs: 800),
        ),
        isTrue,
      );
    });

    test('exactly 1 MB AND 3 s — boundary, notifies', () {
      expect(
        shouldNotifyForPayload(
          _sftpUploadSucceeded(totalBytes: 1024 * 1024, durationMs: 3000),
        ),
        isTrue,
      );
    });

    test('download succeeded uses same rule', () {
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 't',
          title: 'fallback',
          summary: 'fallback',
          success: true,
          kind: 'sftp.download.succeeded',
          data: {
            'fileName': 'baz.zip',
            'totalBytes': 100,
            'durationMs': 50,
          },
        )),
        isFalse,
      );
    });
  });

  group('shouldNotifyForPayload — failures + cancels always notify', () {
    test('failed transfer always notifies regardless of size', () {
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 't',
          title: 'fallback',
          summary: 'fallback',
          success: false,
          kind: 'sftp.upload.failed',
          data: {'totalBytes': 100, 'durationMs': 50},
        )),
        isTrue,
      );
    });

    test('cancelled transfer always notifies', () {
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 't',
          title: 'fallback',
          summary: 'fallback',
          success: false,
          kind: 'sftp.download.cancelled',
          data: {'totalBytes': 100, 'durationMs': 50},
        )),
        isTrue,
      );
    });
  });

  group('shouldNotifyForPayload — AI always notifies', () {
    test('AI succeeded with tiny response still notifies', () {
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 'ai-1',
          title: 'fallback',
          summary: 'fallback',
          success: true,
          kind: 'ai.completion.succeeded',
          data: {'responseLength': 50},
        )),
        isTrue,
      );
    });

    test('AI failed always notifies', () {
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 'ai-1',
          title: 'fallback',
          summary: 'fallback',
          success: false,
          kind: 'ai.completion.failed',
          data: {},
        )),
        isTrue,
      );
    });

    test('AI cancelled always notifies', () {
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 'ai-1',
          title: 'fallback',
          summary: 'fallback',
          success: false,
          kind: 'ai.completion.cancelled',
          data: {},
        )),
        isTrue,
      );
    });
  });

  group('NotificationThresholdConfig — user-tunable', () {
    test('disabling sftpSuccess silences all SFTP succeeded regardless of size',
        () {
      NotificationThresholdConfig.update(const NotificationThresholds(
        sftpSuccessEnabled: false,
      ));
      expect(
        shouldNotifyForPayload(
          _sftpUploadSucceeded(
            totalBytes: 100 * 1024 * 1024,
            durationMs: 60000,
          ),
        ),
        isFalse,
      );
    });

    test('disabling sftpSuccess does not silence failures', () {
      NotificationThresholdConfig.update(const NotificationThresholds(
        sftpSuccessEnabled: false,
      ));
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 't',
          title: 'fallback',
          summary: 'fallback',
          success: false,
          kind: 'sftp.upload.failed',
          data: {'totalBytes': 100, 'durationMs': 50},
        )),
        isTrue,
      );
    });

    test('raising sizeBytes shifts the boundary up', () {
      NotificationThresholdConfig.update(const NotificationThresholds(
        sizeBytes: 10 * 1024 * 1024, // 10 MB
        durationMs: 60000, // 60 s (also raised so duration can't trigger)
      ));
      // 5 MB transfer, 1 s — under both new thresholds.
      expect(
        shouldNotifyForPayload(
          _sftpUploadSucceeded(totalBytes: 5 * 1024 * 1024, durationMs: 1000),
        ),
        isFalse,
      );
      // 12 MB transfer — over size threshold.
      expect(
        shouldNotifyForPayload(
          _sftpUploadSucceeded(totalBytes: 12 * 1024 * 1024, durationMs: 1000),
        ),
        isTrue,
      );
    });

    test('zero thresholds — everything notifies', () {
      NotificationThresholdConfig.update(const NotificationThresholds(
        sizeBytes: 0,
        durationMs: 0,
      ));
      expect(
        shouldNotifyForPayload(
          _sftpUploadSucceeded(totalBytes: 1, durationMs: 1),
        ),
        isTrue,
      );
    });

    test('NotificationThresholds.toJson / fromJson round-trip', () {
      const original = NotificationThresholds(
        sftpSuccessEnabled: false,
        sizeBytes: 5 * 1024 * 1024,
        durationMs: 7000,
      );
      final json = original.toJson();
      final restored = NotificationThresholds.fromJson(json);
      expect(restored, original);
    });

    test('NotificationThresholds.fromJson tolerates missing fields', () {
      final restored = NotificationThresholds.fromJson({});
      expect(restored, NotificationThresholds.defaults);
    });

    test('undoWindowSeconds defaults to 5 and survives copyWith', () {
      expect(NotificationThresholds.defaults.undoWindowSeconds, 5);
      final updated =
          NotificationThresholds.defaults.copyWith(undoWindowSeconds: 12);
      expect(updated.undoWindowSeconds, 12);
      expect(updated.sizeBytes, NotificationThresholds.defaults.sizeBytes);
    });

    test('undoWindowSeconds round-trips through JSON', () {
      const original = NotificationThresholds(undoWindowSeconds: 17);
      final restored = NotificationThresholds.fromJson(original.toJson());
      expect(restored.undoWindowSeconds, 17);
    });

    test('fromJson clamps undoWindowSeconds to [0, 30]', () {
      expect(
        NotificationThresholds.fromJson({'undoWindowSeconds': -5})
            .undoWindowSeconds,
        0,
      );
      expect(
        NotificationThresholds.fromJson({'undoWindowSeconds': 999})
            .undoWindowSeconds,
        30,
      );
      expect(
        NotificationThresholds.fromJson({'undoWindowSeconds': 8})
            .undoWindowSeconds,
        8,
      );
    });

    test('fromJson defaults undoWindowSeconds when missing', () {
      final restored = NotificationThresholds.fromJson({
        'sftpSuccessEnabled': true,
        'sizeBytes': 1024 * 1024,
        'durationMs': 3000,
      });
      expect(
        restored.undoWindowSeconds,
        NotificationThresholds.defaults.undoWindowSeconds,
      );
    });
  });

  group('shouldNotifyForPayload — defaults conservative', () {
    test('unknown kind defaults to notify=true', () {
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 't',
          title: 'fallback',
          summary: 'fallback',
          success: true,
          kind: 'unknown.kind',
        )),
        isTrue,
      );
    });

    test('null kind defaults to notify=true', () {
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 't',
          title: 'fallback',
          summary: 'fallback',
          success: true,
        )),
        isTrue,
      );
    });

    test('missing totalBytes / durationMs defaults to notify=true', () {
      expect(
        shouldNotifyForPayload(const TaskCompletionPayload(
          taskId: 't',
          title: 'fallback',
          summary: 'fallback',
          success: true,
          kind: 'sftp.upload.succeeded',
          data: {'fileName': 'foo'},
        )),
        isTrue,
      );
    });
  });
}
