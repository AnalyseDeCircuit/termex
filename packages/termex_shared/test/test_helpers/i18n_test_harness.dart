/// Shared test harness for widgets that depend on [AppLocalizations].
///
/// Why this exists:
/// During the v0.69.0 i18n migration we kept hitting `_TextWidgetFinder:
/// Found 0 widgets with text "..."` failures because the test `MaterialApp`
/// didn't register `localizationsDelegates` / `supportedLocales`, so
/// `AppLocalizations.of(context)` silently returned the fallback locale (or
/// crashed in stricter setups).
///
/// Use [wrapForI18n] in every widget test that touches a widget which calls
/// `AppLocalizations.of(context)`. It installs the delegates, forces the
/// locale (default `zh` so existing Chinese assertions keep working), and
/// optionally a [ProviderScope] / extra overrides for Riverpod consumers.
///
/// Example:
/// ```dart
/// testWidgets('renders backup history empty state', (tester) async {
///   await tester.pumpWidget(wrapForI18n(
///     const BackupTab(),
///     overrides: [backupHistoryProvider.overrideWith((_) async => [])],
///   ));
///   await tester.pump();
///   expect(find.textContaining('尚无备份记录'), findsOneWidget);
/// });
/// ```
///
/// For text assertions, prefer `find.textContaining` over `find.text` when
/// the ARB value carries trailing punctuation like `！` or `。` — that
/// avoided a real fix-up in v0.69.0 §6.5.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex_shared/l10n/app_localizations.dart';

/// Returns the [child] wrapped in a `MaterialApp` with i18n delegates
/// registered + [Locale] forced + optional Riverpod overrides.
///
/// * [locale] defaults to `zh` to keep existing Chinese widget tests stable.
/// * [overrides] is an optional list of Riverpod overrides forwarded to a
///   `ProviderScope` wrapper. Omit when the widget under test doesn't use
///   Riverpod — the wrapper is still safe (cost is one extra widget).
Widget wrapForI18n(
  Widget child, {
  Locale locale = const Locale('zh'),
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// English variant of [wrapForI18n] for tests that pin English assertions.
Widget wrapForI18nEn(
  Widget child, {
  List<Override> overrides = const [],
}) =>
    wrapForI18n(child, locale: const Locale('en'), overrides: overrides);
