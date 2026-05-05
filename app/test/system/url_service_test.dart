import 'package:flutter_test/flutter_test.dart';

import 'package:termex/system/url_service.dart';

void main() {
  final svc = UrlService.instance;

  group('UrlService', () {
    test('canOpen returns true for https', () {
      expect(svc.canOpen('https://example.com'), isTrue);
    });

    test('canOpen returns true for http', () {
      expect(svc.canOpen('http://localhost:3000'), isTrue);
    });

    test('canOpen returns true for ssh', () {
      expect(svc.canOpen('ssh://user@host'), isTrue);
    });

    test('canOpen returns true for mailto', () {
      expect(svc.canOpen('mailto:user@example.com'), isTrue);
    });

    test('canOpen returns false for ftp', () {
      expect(svc.canOpen('ftp://evil.com'), isFalse);
    });

    test('canOpen returns false for javascript', () {
      expect(svc.canOpen('javascript:alert(1)'), isFalse);
    });

    test('canOpen returns false for file', () {
      expect(svc.canOpen('file:///etc/passwd'), isFalse);
    });

    test('open returns true for allowed scheme', () async {
      final result = await svc.open('https://anthropic.com');
      expect(result, isTrue);
    });

    test('open returns false for disallowed scheme', () async {
      final result = await svc.open('ftp://server.com');
      expect(result, isFalse);
    });

    test('validate throws for disallowed scheme', () {
      expect(
        () => svc.validate('javascript:void(0)'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validate does not throw for allowed scheme', () {
      expect(() => svc.validate('https://safe.com'), returnsNormally);
    });
  });
}
