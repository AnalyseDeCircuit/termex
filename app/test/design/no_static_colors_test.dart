/// Guards the theme migration against regression.
///
/// `TermexColors` holds the *dark* palette as compile-time constants. A widget
/// that reads them paints dark no matter which theme is active — which is why
/// choosing "Light" in Settings used to change nothing on screen. Widgets must
/// resolve colours from the active scope instead (`context.colors.x`), or take
/// an injected `TermexColorScheme` when they have no `BuildContext`.
///
/// This test fails on any new reference outside the allowlist below. If you
/// are adding one, you almost certainly want `context.colors` — see
/// `packages/termex_shared/lib/design/colors.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Paths (relative to the repo root) permitted to read the raw constants,
/// each with the reason it cannot go through a `TermexThemeScope`.
const _allowed = <String, String>{
  // Defines the constants and the scheme built from them.
  'packages/termex_shared/lib/design/colors.dart': 'declares the palette',
  // Paints before the first frame, above any theme scope, and deliberately
  // matches the native Android/iOS launch screen colour.
  'packages/termex_shared/lib/system/splash_gate.dart': 'pre-first-frame splash',
  // Sets the Android system navigation bar via SystemChrome during bootstrap,
  // before any widget tree exists.
  'app/lib/main.dart': 'system UI overlay style set during bootstrap',
  // A deterministic identicon palette keyed off initials — these are identity
  // colours that must stay stable across themes, not app chrome.
  'packages/termex_shared/lib/widgets/avatar.dart': 'identicon palette',
};

/// The dark palette spelled out as literals.
///
/// `TermexIconWidget` defaulted its colour to `const Color(0xFFE6EDF3)` — the
/// dark `textPrimary`, written out longhand. It escaped a `TermexColors` grep
/// entirely while still painting dark under a light theme, which is exactly
/// the bug this migration removes. Catching the literals closes that hole.
final _paletteLiterals = RegExp(
  r'0xFF(0D1117|161B22|21262D|2F81F7|3FB950|D29922|F85149|8B949E|E6EDF3'
  r'|7D8590|484F58|30363D)',
  caseSensitive: false,
);

/// Resolves the repo root from the test's working directory (`app/`).
///
/// Identified by holding both workspaces — the repo root itself has no
/// pubspec, so `app/` would otherwise match first.
Directory _repoRoot() {
  var dir = Directory.current;
  while (!(Directory('${dir.path}/app/lib').existsSync() &&
      Directory('${dir.path}/packages/termex_shared/lib').existsSync())) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('could not locate the repo root from ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  test('no widget code reads the static TermexColors constants', () {
    final root = _repoRoot();
    final roots = [
      Directory('${root.path}/packages/termex_shared/lib'),
      Directory('${root.path}/app/lib'),
    ];

    final offenders = <String>[];
    for (final dir in roots) {
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final rel = entity.path.substring(root.path.length + 1);
        if (_allowed.containsKey(rel)) continue;

        // Read as bytes and decode leniently: terminal_pane.dart embeds real
        // NUL and 0x1f control bytes inside a raw-string URL regex, which
        // makes grep classify it as binary and skip it silently. That is how
        // its ten stale colour reads survived the first migration sweep — so
        // this guard must never depend on the same classification.
        final lines = const LineSplitter()
            .convert(utf8.decode(entity.readAsBytesSync(), allowMalformed: true));
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Doc comments and examples may still name the class.
          if (line.trimLeft().startsWith('//')) continue;
          if (line.contains('TermexColors.') ||
              _paletteLiterals.hasMatch(line)) {
            offenders.add('$rel:${i + 1}: ${line.trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These read the compile-time dark palette and will not follow '
          'the active theme. Use `context.colors.<name>` inside a build '
          'method, or take a `TermexColorScheme` parameter where no '
          'BuildContext is available. Genuine exceptions go in `_allowed` '
          'in this file, with a reason.\n  ${offenders.join('\n  ')}',
    );
  });
}
