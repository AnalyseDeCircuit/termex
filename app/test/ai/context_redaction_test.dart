import 'package:flutter_test/flutter_test.dart';

import 'package:termex/features/ai/state/ai_stream_provider.dart';

void main() {
  group('AiStreamNotifier.redactSensitive', () {
    test('redacts password: lines', () {
      const input = 'Connecting...\nPassword: secret\nConnected.';
      final result = AiStreamNotifier.redactSensitive(input);
      expect(result, isNot(contains('secret')));
      expect(result, contains('[REDACTED]'));
    });

    test('redacts passphrase: lines', () {
      const input = 'Enter passphrase: my-key-passphrase\nOK';
      final result = AiStreamNotifier.redactSensitive(input);
      expect(result, isNot(contains('my-key-passphrase')));
    });

    test('redacts "Password for" lines', () {
      const input = 'Password for alice@host.com:\nAuthenticated';
      final result = AiStreamNotifier.redactSensitive(input);
      expect(result.split('\n').first, equals('[REDACTED]'));
    });

    test('leaves non-sensitive lines intact', () {
      const input = 'ls -la\ntotal 48\ndrwxr-xr-x 2 user group 64 Jan 1';
      final result = AiStreamNotifier.redactSensitive(input);
      expect(result, equals(input));
    });

    test('multiple sensitive lines all redacted', () {
      const input = 'password: abc\npassphrase: def\nnormal line';
      final result = AiStreamNotifier.redactSensitive(input);
      final lines = result.split('\n');
      expect(lines[0], equals('[REDACTED]'));
      expect(lines[1], equals('[REDACTED]'));
      expect(lines[2], equals('normal line'));
    });
  });

  group('AiStreamNotifier.buildContext', () {
    test('trims to max lines (keeps tail)', () {
      final lines = List.generate(200, (i) => 'line $i');
      final raw = lines.join('\n');
      final result = AiStreamNotifier.buildContext(raw, 100);
      expect(result.split('\n').length, equals(100));
      expect(result, contains('line 199'));
      expect(result, isNot(contains('line 0')));
    });

    test('truncates long lines at 500 chars', () {
      final longLine = 'A' * 600;
      final result = AiStreamNotifier.buildContext(longLine, 10);
      final firstLine = result.split('\n').first;
      expect(firstLine.length, lessThan(600));
      expect(firstLine, contains('[...截断]'));
    });

    test('leaves short input unchanged', () {
      const raw = 'echo hello\necho world';
      final result = AiStreamNotifier.buildContext(raw, 100);
      expect(result, equals(raw));
    });

    test('returns all lines when under limit', () {
      final lines = List.generate(50, (i) => 'cmd $i');
      final raw = lines.join('\n');
      final result = AiStreamNotifier.buildContext(raw, 100);
      expect(result.split('\n').length, equals(50));
    });
  });
}
