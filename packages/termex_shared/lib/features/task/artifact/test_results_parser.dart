/// Schema parser for `task.artifact { kind: "test_results", payload }`.
///
/// The MCP adapter emits a structured payload; this turns it into a
/// strongly-typed Dart object the [TestResultList] widget consumes.
/// Unknown payload shapes degrade gracefully to an empty summary
/// rather than throwing.
library;

class TestSummary {
  final int passed;
  final int failed;
  final int skipped;
  final int? durationMs;

  const TestSummary({
    required this.passed,
    required this.failed,
    required this.skipped,
    this.durationMs,
  });

  int get total => passed + failed + skipped;

  factory TestSummary.empty() =>
      const TestSummary(passed: 0, failed: 0, skipped: 0);

  factory TestSummary.fromJson(Map<String, dynamic>? j) {
    if (j == null) return TestSummary.empty();
    return TestSummary(
      passed: (j['passed'] as num?)?.toInt() ?? 0,
      failed: (j['failed'] as num?)?.toInt() ?? 0,
      skipped: (j['skipped'] as num?)?.toInt() ?? 0,
      durationMs: (j['duration_ms'] as num?)?.toInt(),
    );
  }
}

class TestFailure {
  final String testName;
  final String? message;
  final String? file;
  final int? line;

  const TestFailure({
    required this.testName,
    this.message,
    this.file,
    this.line,
  });

  factory TestFailure.fromJson(Map<String, dynamic> j) => TestFailure(
        testName: j['test'] as String? ?? '<unknown>',
        message: j['message'] as String?,
        file: j['file'] as String?,
        line: (j['line'] as num?)?.toInt(),
      );
}

class TestResultsPayload {
  final String framework;
  final TestSummary summary;
  final List<TestFailure> failures;

  const TestResultsPayload({
    required this.framework,
    required this.summary,
    required this.failures,
  });

  factory TestResultsPayload.fromJson(Map<String, dynamic> j) {
    return TestResultsPayload(
      framework: j['framework'] as String? ?? 'unknown',
      summary: TestSummary.fromJson(j['summary'] as Map<String, dynamic>?),
      failures: (j['failures'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(TestFailure.fromJson)
              .toList() ??
          const [],
    );
  }
}
