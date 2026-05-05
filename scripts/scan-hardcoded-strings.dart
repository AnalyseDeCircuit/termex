#!/usr/bin/env dart
/// Scans all *.dart files under app/lib/ for hardcoded user-visible strings.
///
/// A string is flagged when:
///   1. It appears as a string literal (single or double quoted).
///   2. It contains at least one Chinese character OR is longer than 5 chars
///      and starts with an uppercase letter (English UI label heuristic).
///   3. It is NOT an ARB key reference, a const symbol, or an import path.
///
/// Usage: dart scripts/scan-hardcoded-strings.dart
/// Exit code 0 = no violations; exit code 1 = violations found.
library;

import 'dart:io';

final _chineseRe = RegExp(r'[\u4e00-\u9fff]');
final _englishLabelRe = RegExp(r"^[A-Z][A-Za-z ]{5,}$");

// Patterns to ignore (ARB calls, imports, assertions, URLs, log messages).
final _allowlistRe = RegExp(
  r"AppLocalizations\.of|l10n\.|intl\.|import |//|assert|'package:|'dart:|'http|CLAUDE|TODO|FIXME|print\(|debugPrint\(|developer\.log",
);

int main() {
  final libDir = Directory('app/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('Run from the repository root.');
    return 2;
  }

  final violations = <String>[];

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_allowlistRe.hasMatch(line)) continue;

      // Extract all string literals on this line.
      for (final match in RegExp(r"""(?:'([^']*)'|"([^"]*)")""").allMatches(line)) {
        final s = match.group(1) ?? match.group(2) ?? '';
        if (s.isEmpty) continue;
        if (_chineseRe.hasMatch(s) ||
            (_englishLabelRe.hasMatch(s) && s.length > 5)) {
          violations.add('${entity.path}:${i + 1}: "$s"');
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('✅ No hardcoded user-visible strings found.');
    return 0;
  }

  stderr.writeln('❌ ${violations.length} hardcoded string(s) found:');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  return 1;
}
