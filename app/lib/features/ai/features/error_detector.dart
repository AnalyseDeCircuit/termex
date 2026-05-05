/// Scans terminal output for error patterns and surfaces diagnose actions.

// ─── Models ───────────────────────────────────────────────────────────────────

enum ErrorSeverity { warning, error, critical }

class DetectedError {
  final String rawLine;
  final ErrorSeverity severity;
  final String? errorCode;
  final String? suggestedQuery;

  const DetectedError({
    required this.rawLine,
    required this.severity,
    this.errorCode,
    this.suggestedQuery,
  });
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class ErrorDetector {
  static final _errorPatterns = [
    _ErrorPattern(
      regex: RegExp(r'(FATAL|fatal):?\s+(.+)', caseSensitive: false),
      severity: ErrorSeverity.critical,
      buildQuery: (m) => '解释这个严重错误：${m.group(0)}',
    ),
    _ErrorPattern(
      regex: RegExp(r'panic:?\s+(.+)'),
      severity: ErrorSeverity.critical,
      buildQuery: (m) => '解释这个 panic：${m.group(0)}',
    ),
    _ErrorPattern(
      regex: RegExp(r'SIGKILL|SIGSEGV|Segmentation fault'),
      severity: ErrorSeverity.critical,
      buildQuery: (m) => '诊断这个信号崩溃：${m.group(0)}',
    ),
    _ErrorPattern(
      regex: RegExp(r'(ERROR|error|Error):?\s+(.+)'),
      severity: ErrorSeverity.error,
      buildQuery: (m) => '帮我诊断这个错误：${m.group(0)}',
    ),
    _ErrorPattern(
      regex: RegExp(r'(WARN|WARNING|warning):?\s+(.+)', caseSensitive: false),
      severity: ErrorSeverity.warning,
      buildQuery: (m) => '解释这个警告：${m.group(0)}',
    ),
    _ErrorPattern(
      regex: RegExp(r'Traceback \(most recent call last\)'),
      severity: ErrorSeverity.error,
      buildQuery: (_) => '帮我诊断这个 Python traceback',
    ),
    _ErrorPattern(
      regex: RegExp(r'command not found'),
      severity: ErrorSeverity.error,
      buildQuery: (m) => '如何解决 "command not found"？',
    ),
    _ErrorPattern(
      regex: RegExp(r'Permission denied'),
      severity: ErrorSeverity.error,
      buildQuery: (_) => '如何解决 "Permission denied"？',
    ),
    _ErrorPattern(
      regex: RegExp(r'No such file or directory'),
      severity: ErrorSeverity.error,
      buildQuery: (_) => '如何解决 "No such file or directory"？',
    ),
    _ErrorPattern(
      regex: RegExp(r'Connection (refused|timed out|reset)'),
      severity: ErrorSeverity.error,
      buildQuery: (m) => '诊断网络连接问题：${m.group(0)}',
    ),
    _ErrorPattern(
      regex: RegExp(r'exit code (\d+)', caseSensitive: false),
      severity: ErrorSeverity.error,
      buildQuery: (m) => '解释命令退出码 ${m.group(1)}',
    ),
  ];

  /// Scan [lines] of terminal output for errors.
  List<DetectedError> scan(List<String> lines) {
    final results = <DetectedError>[];
    for (final line in lines) {
      final cleaned = _stripAnsi(line);
      for (final pattern in _errorPatterns) {
        final match = pattern.regex.firstMatch(cleaned);
        if (match != null) {
          results.add(DetectedError(
            rawLine: cleaned,
            severity: pattern.severity,
            suggestedQuery: pattern.buildQuery(match),
          ));
          break; // first matching pattern wins
        }
      }
    }
    return results;
  }

  String _stripAnsi(String s) =>
      s.replaceAll(RegExp(r'\x1B\[[0-9;]*[mK]'), '');
}

class _ErrorPattern {
  final RegExp regex;
  final ErrorSeverity severity;
  final String Function(RegExpMatch) buildQuery;

  const _ErrorPattern({
    required this.regex,
    required this.severity,
    required this.buildQuery,
  });
}
