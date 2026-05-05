import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/ai/features/error_detector.dart';

void main() {
  late ErrorDetector detector;

  setUp(() => detector = ErrorDetector());

  group('ErrorDetector', () {
    test('detects ERROR keyword', () {
      final results = detector.scan(['ERROR: connection refused']);
      expect(results, hasLength(1));
      expect(results.first.severity, ErrorSeverity.error);
    });

    test('detects FATAL as critical', () {
      final results = detector.scan(['FATAL: out of memory']);
      expect(results.first.severity, ErrorSeverity.critical);
    });

    test('detects WARNING', () {
      final results = detector.scan(['WARNING: deprecated API used']);
      expect(results.first.severity, ErrorSeverity.warning);
    });

    test('detects panic as critical', () {
      final results = detector.scan(['panic: runtime error: index out of range']);
      expect(results.first.severity, ErrorSeverity.critical);
    });

    test('returns empty for clean output', () {
      final results = detector.scan(['ls: 3 files', 'done']);
      expect(results, isEmpty);
    });

    test('strips ANSI codes before matching', () {
      final results =
          detector.scan(['\x1B[31mERROR\x1B[0m: something failed']);
      expect(results, hasLength(1));
    });

    test('detects command not found', () {
      final results = detector.scan(['bash: foo: command not found']);
      expect(results.first.severity, ErrorSeverity.error);
    });

    test('provides suggested query', () {
      final results = detector.scan(['Permission denied']);
      expect(results.first.suggestedQuery, isNotNull);
    });
  });
}
