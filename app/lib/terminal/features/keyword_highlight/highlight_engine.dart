/// Keyword highlighting engine for terminal output.
///
/// Each [HighlightRule] pairs a [RegExp] with a [HighlightColor].  The
/// [HighlightEngine] scans a line of text and returns [HighlightSpan]s that
/// the terminal renderer overlays on top of the existing cell colours.
///
/// The engine deliberately does *not* modify the underlying Screen buffer —
/// highlights are applied only during rendering so that they do not interfere
/// with the search engine or clipboard operations.
library;

import 'package:flutter/painting.dart' show Color;

// ─── Data model ──────────────────────────────────────────────────────────────

/// A colour token for a highlight rule.
class HighlightColor {
  final Color foreground;
  final Color? background;
  final bool bold;

  const HighlightColor({
    required this.foreground,
    this.background,
    this.bold = false,
  });

  static const red = HighlightColor(foreground: Color(0xFFF38BA8));
  static const yellow = HighlightColor(foreground: Color(0xFFF9E2AF));
  static const green = HighlightColor(foreground: Color(0xFFA6E3A1));
  static const cyan = HighlightColor(foreground: Color(0xFF89DCEB));
  static const blue = HighlightColor(foreground: Color(0xFF89B4FA));
  static const magenta = HighlightColor(foreground: Color(0xFFCBA6F7));
}

/// A single keyword → colour rule.
class HighlightRule {
  final RegExp pattern;
  final HighlightColor color;
  final bool enabled;

  const HighlightRule({
    required this.pattern,
    required this.color,
    this.enabled = true,
  });

  /// Convenience constructor from a plain regex string.
  factory HighlightRule.fromString(
    String regex, {
    required HighlightColor color,
    bool caseInsensitive = false,
    bool enabled = true,
  }) {
    return HighlightRule(
      pattern: RegExp(regex, caseSensitive: !caseInsensitive),
      color: color,
      enabled: enabled,
    );
  }
}

/// A highlight span inside a line of text.
class HighlightSpan {
  final int start;
  final int end;
  final HighlightColor color;

  const HighlightSpan({
    required this.start,
    required this.end,
    required this.color,
  });
}

// ─── Engine ──────────────────────────────────────────────────────────────────

/// Applies a list of [HighlightRule]s to terminal text lines.
///
/// Rules are evaluated in order.  When two rules match the same range the
/// first (higher-priority) rule wins.
class HighlightEngine {
  /// The built-in default rule set modelled after the Vue version's defaults.
  static final List<HighlightRule> defaultRules = [
    HighlightRule.fromString(
      r'\b(error|err|fatal|panic|exception)\b',
      color: HighlightColor.red,
      caseInsensitive: true,
    ),
    HighlightRule.fromString(
      r'\b(warning|warn)\b',
      color: HighlightColor.yellow,
      caseInsensitive: true,
    ),
    HighlightRule.fromString(
      r'\b(success|ok|done|passed)\b',
      color: HighlightColor.green,
      caseInsensitive: true,
    ),
    HighlightRule.fromString(
      r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}',
      color: HighlightColor.cyan,
    ),
  ];

  final List<HighlightRule> rules;

  const HighlightEngine({this.rules = const []});

  HighlightEngine.withDefaults({List<HighlightRule> extra = const []})
      : rules = [...defaultRules, ...extra];

  /// Returns all highlight spans in [text], non-overlapping.
  ///
  /// Spans are sorted by [HighlightSpan.start].
  List<HighlightSpan> highlight(String text) {
    final spans = <HighlightSpan>[];

    for (final rule in rules) {
      if (!rule.enabled) continue;
      for (final m in rule.pattern.allMatches(text)) {
        if (_overlaps(spans, m.start, m.end)) continue;
        spans.add(HighlightSpan(
          start: m.start,
          end: m.end,
          color: rule.color,
        ));
      }
    }

    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }

  static bool _overlaps(List<HighlightSpan> existing, int start, int end) {
    for (final s in existing) {
      if (start < s.end && end > s.start) return true;
    }
    return false;
  }
}
