import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/task/artifact/test_results_parser.dart';

void main() {
  test('TestResultsPayload.fromJson parses full payload', () {
    final p = TestResultsPayload.fromJson({
      'framework': 'cargo test',
      'summary': {
        'passed': 24,
        'failed': 2,
        'skipped': 1,
        'duration_ms': 12500,
      },
      'failures': [
        {
          'test': 'test_user_login',
          'message': 'expected true, got false',
          'file': 'src/auth.rs',
          'line': 42,
        },
        {'test': 'test_other'},
      ],
    });
    expect(p.framework, 'cargo test');
    expect(p.summary.passed, 24);
    expect(p.summary.failed, 2);
    expect(p.summary.skipped, 1);
    expect(p.summary.durationMs, 12500);
    expect(p.summary.total, 27);
    expect(p.failures, hasLength(2));
    expect(p.failures.first.testName, 'test_user_login');
    expect(p.failures.first.file, 'src/auth.rs');
    expect(p.failures.first.line, 42);
    expect(p.failures.last.testName, 'test_other');
    expect(p.failures.last.file, isNull);
  });

  test('tolerates empty / missing payload', () {
    final p = TestResultsPayload.fromJson({});
    expect(p.framework, 'unknown');
    expect(p.summary.total, 0);
    expect(p.failures, isEmpty);
  });

  test('TestSummary.empty is zeros', () {
    final s = TestSummary.empty();
    expect(s.passed, 0);
    expect(s.failed, 0);
    expect(s.skipped, 0);
    expect(s.total, 0);
  });
}
